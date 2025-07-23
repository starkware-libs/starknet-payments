#[starknet::contract]
pub mod payments {
    use core::num::traits::Zero;
    use core::panic_with_felt252;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::utils::snip12::{OffchainMessageHash, SNIP12Metadata};
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starkware_utils::components::pausable::PausableComponent;
    use starkware_utils::components::pausable::PausableComponent::InternalTrait as PausableInternal;
    use starkware_utils::components::replaceability::ReplaceabilityComponent;
    use starkware_utils::components::replaceability::ReplaceabilityComponent::InternalReplaceabilityTrait;
    use starkware_utils::components::roles::RolesComponent;
    use starkware_utils::components::roles::RolesComponent::InternalTrait as RolesInternal;
    use starkware_utils::math::utils::mul_wide_and_ceil_div;
    use starkware_utils::signature::stark::HashType;
    use starkware_utils::time::time::Time;
    use crate::errors::{
        INVALID_AMOUNT, INVALID_AMOUNT_RATIO, INVALID_DOWNCAST_AFTER_DIVISION, INVALID_HIGH_FEE,
        INVALID_HIGH_FEE_LIMIT, INVALID_TOKEN_PAIR, INVALID_ZERO_ADDRESS, INVALID_ZERO_TOKEN,
        ORDER_ALREADY_CANCELED, ORDER_ALREADY_FULFILLED, ORDER_EXPIRED, ORDER_WAS_CANCELED,
        ORDER_WAS_FULFILLED, TOKEN_ALREADY_REGISTERED, TOKEN_NOT_REGISTERED, TRANSFER_FAILED,
    };
    use crate::interface::{FulfilledStatus, IPayments, Signature};
    use crate::order::Order;
    use crate::utils::{assert_valid_signature, validate_match_orders};

    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(path: ReplaceabilityComponent, storage: replaceability, event: ReplaceabilityEvent);
    component!(path: RolesComponent, storage: roles, event: RolesEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // External

    #[abi(embed_v0)]
    impl ReplaceabilityImpl =
        ReplaceabilityComponent::ReplaceabilityImpl<ContractState>;

    #[abi(embed_v0)]
    impl RolesImpl = RolesComponent::RolesImpl<ContractState>;

    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;

    const MAX_BASIS_POINTS: u32 = 10000;

    const NAME: felt252 = 'Madu';
    const VERSION: felt252 = 'v0';

    /// Required for hash computation.
    pub impl SNIP12MetadataImpl of SNIP12Metadata {
        fn name() -> felt252 {
            NAME
        }
        fn version() -> felt252 {
            VERSION
        }
    }

    #[storage]
    struct Storage {
        // --- Components ---
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        #[substorage(v0)]
        pub replaceability: ReplaceabilityComponent::Storage,
        #[substorage(v0)]
        pub roles: RolesComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        // --- Payment ---
        fee_limit: u128,
        fee_recipient: ContractAddress,
        fee: u128,
        // Whitelisted tokens.
        tokens: Map<ContractAddress, bool>,
        // Order hash to fulfilled absolute base amount.
        fulfillment: Map<HashType, FulfilledStatus>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        #[flat]
        ReplaceabilityEvent: ReplaceabilityComponent::Event,
        #[flat]
        RolesEvent: RolesComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }


    #[constructor]
    pub fn constructor(
        ref self: ContractState,
        governance_admin: ContractAddress,
        upgrade_delay: u64,
        fee_limit: u128,
        fee_recipient: ContractAddress,
        fee: u128,
    ) {
        self.roles.initialize(:governance_admin);
        self.replaceability.initialize(:upgrade_delay);

        self._set_fee_limit(:fee_limit);
        self._set_fee_recipient(recipient: fee_recipient);
        self._set_fee(:fee);
    }

    // TODO(Mohammad): implement the IPayments trait methods.
    #[abi(embed_v0)]
    pub impl PaymentsImpl of IPayments<ContractState> {
        fn trade(
            ref self: ContractState,
            buyer_order: Order,
            seller_order: Order,
            buyer_signature: Signature,
            seller_signature: Signature,
            actual_sell_amount: u128,
            actual_buy_amount: u128,
        ) {
            self.pausable.assert_not_paused();

            /// Trade validation:

            // Validate orders.
            let order_hash_1 = self
                ._validate_order(
                    order: buyer_order,
                    signature: buyer_signature,
                    :actual_sell_amount,
                    :actual_buy_amount,
                );
            let order_hash_2 = self
                ._validate_order(
                    order: seller_order,
                    signature: seller_signature,
                    // The actual amounts are from `buyer_order`'s perspective; they're reversed for
                    // `seller_order`.
                    actual_sell_amount: actual_buy_amount,
                    actual_buy_amount: actual_sell_amount,
                );

            assert(self.is_token_registered(buyer_order.sell_token), TOKEN_NOT_REGISTERED);
            assert(self.is_token_registered(buyer_order.buy_token), TOKEN_NOT_REGISTERED);

            validate_match_orders(
                :buyer_order, :seller_order, :actual_sell_amount, :actual_buy_amount,
            );

            /// Trade execution:

            // Update the fulfillment.
            self
                ._apply_fulfillment(
                    order_hash: order_hash_1,
                    actual_amount: actual_sell_amount,
                    order_amount: buyer_order.sell_amount,
                );
            self
                ._apply_fulfillment(
                    order_hash: order_hash_2,
                    actual_amount: actual_buy_amount,
                    order_amount: seller_order.sell_amount,
                );

            let sell_token = IERC20Dispatcher { contract_address: buyer_order.sell_token };
            let buy_token = IERC20Dispatcher { contract_address: buyer_order.buy_token };

            // Take fees.
            let fee_recipient = self.fee_recipient.read();
            let fee_1 = self._calculate_fee(actual_sell_amount);
            // The actual amounts are from `buyer_order`'s perspective; they're reversed for
            // `seller_order`.
            let fee_2 = self._calculate_fee(actual_buy_amount);
            assert(
                sell_token.transfer_from(buyer_order.maker, fee_recipient, fee_1.into()),
                TRANSFER_FAILED,
            );
            assert(
                buy_token.transfer_from(seller_order.maker, fee_recipient, fee_2.into()),
                TRANSFER_FAILED,
            );

            // Transfer the actual amounts.
            assert(
                sell_token
                    .transfer_from(
                        buyer_order.maker, seller_order.maker, (actual_sell_amount - fee_1).into(),
                    ),
                TRANSFER_FAILED,
            );
            assert(
                buy_token
                    .transfer_from(
                        seller_order.maker, buyer_order.maker, (actual_buy_amount - fee_2).into(),
                    ),
                TRANSFER_FAILED,
            );
        }

        fn register_token(ref self: ContractState, token: ContractAddress) {
            self.roles.only_app_governor();

            assert(token.is_non_zero(), INVALID_ZERO_ADDRESS);
            assert(!self.is_token_registered(token), TOKEN_ALREADY_REGISTERED);
            self.tokens.write(token, true);
        }
        fn remove_token(ref self: ContractState, token: ContractAddress) {
            self.roles.only_app_governor();

            assert(self.is_token_registered(token), TOKEN_NOT_REGISTERED);
            self.tokens.write(token, false);
        }
        fn is_token_registered(self: @ContractState, token: ContractAddress) -> bool {
            self.tokens.read(token)
        }

        fn cancel_orders(ref self: ContractState, order_hashes: Span<HashType>) {
            self.roles.only_operator();

            for order_hash in order_hashes {
                self._cancel_order(order_hash: *order_hash);
            }
        }

        // Setters:

        fn set_fee_limit(ref self: ContractState, fee_limit: u128) {
            self.roles.only_app_governor();

            self._set_fee_limit(:fee_limit);
        }

        fn set_fee(ref self: ContractState, fee: u128) {
            self.roles.only_operator();

            self._set_fee(:fee);
        }
        fn set_fee_recipient(ref self: ContractState, recipient: ContractAddress) {
            self.roles.only_operator();

            self._set_fee_recipient(:recipient);
        }

        // Getters:

        fn get_fee_limit(self: @ContractState) -> u128 {
            self.fee_limit.read()
        }
        fn get_fee(self: @ContractState) -> u128 {
            self.fee.read()
        }
        fn get_fee_recipient(self: @ContractState) -> ContractAddress {
            self.fee_recipient.read()
        }

        fn get_order_fulfillment(self: @ContractState, order_hash: HashType) -> FulfilledStatus {
            self.fulfillment.read(order_hash)
        }
    }


    // Internal methods
    #[generate_trait]
    pub impl ImplInternalPayments of InternalPaymentsTrait {
        fn _set_fee_limit(ref self: ContractState, fee_limit: u128) {
            assert(fee_limit <= MAX_BASIS_POINTS.into(), INVALID_HIGH_FEE_LIMIT);
            self.fee_limit.write(fee_limit);
        }

        fn _set_fee(ref self: ContractState, fee: u128) {
            assert(fee <= self.fee_limit.read(), INVALID_HIGH_FEE);
            self.fee.write(fee);
        }

        fn _set_fee_recipient(ref self: ContractState, recipient: ContractAddress) {
            assert(recipient.is_non_zero(), INVALID_ZERO_ADDRESS);
            self.fee_recipient.write(recipient);
        }

        fn _validate_fulfillment(
            self: @ContractState, order_hash: HashType, actual_amount: u128, order_amount: u128,
        ) {
            let fulfillment_entry = self.fulfillment.entry(order_hash);
            match fulfillment_entry.read() {
                FulfilledStatus::Fulfilled(_) => { panic_with_felt252(ORDER_ALREADY_FULFILLED); },
                FulfilledStatus::PartialFulfilled(fulfilled_amount) => {
                    assert(fulfilled_amount + actual_amount <= order_amount, INVALID_AMOUNT);
                },
                FulfilledStatus::Canceled(_) => { panic_with_felt252(ORDER_WAS_CANCELED); },
            }
        }

        fn _apply_fulfillment(
            ref self: ContractState, order_hash: HashType, actual_amount: u128, order_amount: u128,
        ) {
            let fulfillment_entry = self.fulfillment.entry(order_hash);
            match fulfillment_entry.read() {
                FulfilledStatus::Fulfilled(_) => { panic_with_felt252(ORDER_ALREADY_FULFILLED); },
                FulfilledStatus::PartialFulfilled(fulfilled_amount) => {
                    let total_amount = fulfilled_amount + actual_amount;
                    if total_amount < order_amount {
                        fulfillment_entry.write(FulfilledStatus::PartialFulfilled(total_amount));
                    } else {
                        fulfillment_entry.write(FulfilledStatus::Fulfilled(total_amount));
                    }
                },
                FulfilledStatus::Canceled(_) => { panic_with_felt252(ORDER_WAS_CANCELED); },
            }
        }

        fn _cancel_order(ref self: ContractState, order_hash: HashType) {
            match self.fulfillment.read(order_hash) {
                FulfilledStatus::Fulfilled(_) => { panic_with_felt252(ORDER_WAS_FULFILLED); },
                FulfilledStatus::PartialFulfilled(fulfilled_amount) => {
                    self.fulfillment.write(order_hash, FulfilledStatus::Canceled(fulfilled_amount));
                },
                FulfilledStatus::Canceled(_) => { panic_with_felt252(ORDER_ALREADY_CANCELED); },
            }
        }

        fn _validate_order(
            self: @ContractState,
            order: Order,
            signature: Signature,
            actual_sell_amount: u128,
            actual_buy_amount: u128,
        ) -> HashType {
            assert(order.expiry >= Time::now(), ORDER_EXPIRED);
            assert(order.maker.is_non_zero(), INVALID_ZERO_ADDRESS);

            assert(order.sell_amount >= actual_sell_amount, INVALID_AMOUNT);
            assert(order.buy_amount >= actual_buy_amount, INVALID_AMOUNT);

            assert(order.sell_token.is_non_zero(), INVALID_ZERO_TOKEN);
            assert(order.buy_token.is_non_zero(), INVALID_ZERO_TOKEN);
            assert(order.sell_token != order.buy_token, INVALID_TOKEN_PAIR);

            assert(
                order.sell_amount * actual_buy_amount <= order.buy_amount * actual_sell_amount,
                INVALID_AMOUNT_RATIO,
            );

            let order_hash = order.get_message_hash(order.maker);
            self
                ._validate_fulfillment(
                    order_hash: order_hash,
                    actual_amount: actual_sell_amount,
                    order_amount: order.sell_amount,
                );

            // Validate the signature.
            let (r, s) = signature;
            assert_valid_signature(
                signer: order.maker, hash: order_hash, signature: array![r, s].span(),
            );

            order_hash
        }


        fn _calculate_fee(self: @ContractState, amount: u128) -> u128 {
            let fee = self.fee.read();

            mul_wide_and_ceil_div(amount, fee, MAX_BASIS_POINTS.into())
                .expect(INVALID_DOWNCAST_AFTER_DIVISION)
        }
    }
}

