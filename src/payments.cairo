#[starknet::contract]
pub mod payments {
    use core::num::traits::Zero;
    use core::panic_with_felt252;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::utils::snip12::SNIP12Metadata;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starkware_utils::components::pausable::PausableComponent;
    use starkware_utils::components::pausable::PausableComponent::InternalTrait as PausableInternal;
    use starkware_utils::components::replaceability::ReplaceabilityComponent;
    use starkware_utils::components::replaceability::ReplaceabilityComponent::InternalReplaceabilityTrait;
    use starkware_utils::components::roles::RolesComponent;
    use starkware_utils::components::roles::RolesComponent::InternalTrait as RolesInternal;
    use starkware_utils::signature::stark::{HashType, Signature};
    use crate::errors::{
        INVALID_HIGH_FEE, INVALID_HIGH_FEE_LIMIT, INVALID_ZERO_ADDRESS, ORDER_ALREADY_CANCELED,
        ORDER_WAS_FULFILLED, TOKEN_ALREADY_REGISTERED, TOKEN_NOT_REGISTERED, TRANSFER_FAILED,
    };
    use crate::interface::{FulfilledStatus, IPayments};
    use crate::order::Order;

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
            order_1: Order,
            order_2: Order,
            signature_1: Signature,
            signature_2: Signature,
            actual_sell_amount: u128,
            actual_buy_amount: u128,
        ) {
            self.pausable.assert_not_paused();

            // Validate orders.
            let order_hash_1 = self
                ._validate_order(
                    order: order_1, signature: signature_1, :actual_sell_amount, :actual_buy_amount,
                );
            let order_hash_2 = self
                ._validate_order(
                    order: order_2, signature: signature_2, :actual_sell_amount, :actual_buy_amount,
                );

            self
                ._validate_match_orders(
                    :order_1, :order_2, :actual_sell_amount, :actual_buy_amount,
                );

            // Update the fulfillment.
            self
                ._apply_fill(
                    order_hash: order_hash_1,
                    actual_amount: actual_sell_amount,
                    order_amount: order_1.sell_amount,
                );
            self
                ._apply_fill(
                    order_hash: order_hash_2,
                    actual_amount: actual_buy_amount,
                    order_amount: order_2.sell_amount,
                );

            let sell_token = IERC20Dispatcher { contract_address: order_1.sell_token };
            let buy_token = IERC20Dispatcher { contract_address: order_1.buy_token };

            // Take fees.
            let fee_recipient = self.fee_recipient.read();
            let fee_1 = self._calculate_fee(actual_sell_amount);
            let fee_2 = self._calculate_fee(actual_buy_amount);
            assert(
                sell_token.transfer_from(order_1.owner, fee_recipient, fee_1.into()),
                TRANSFER_FAILED,
            );
            assert(
                buy_token.transfer_from(order_2.owner, fee_recipient, fee_2.into()),
                TRANSFER_FAILED,
            );

            // Transfer the actual amounts.
            assert(
                sell_token
                    .transfer_from(
                        order_1.owner, order_2.owner, (actual_sell_amount - fee_1).into(),
                    ),
                TRANSFER_FAILED,
            );
            assert(
                buy_token
                    .transfer_from(
                        order_2.owner, order_1.owner, (actual_buy_amount - fee_2).into(),
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

        fn _apply_fill(
            ref self: ContractState, order_hash: HashType, actual_amount: u128, order_amount: u128,
        ) { // TODO(Mohammad): Implement updating the fulfillment status.
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
        ) -> HashType { // TODO(Mohammad): Implement order validation logic.
            // This should include checking the order's expiry, signature validity, and amounts.
            Default::default()
        }

        fn _validate_match_orders(
            self: @ContractState,
            order_1: Order,
            order_2: Order,
            actual_sell_amount: u128,
            actual_buy_amount: u128,
        ) { // TODO(Mohammad): Implement logic to validate the two orders.
        // This should include checking that the orders are compatible and that the amounts match.
        }

        fn _calculate_fee(self: @ContractState, amount: u128) -> u128 {
            let fee = self.fee.read();
            // TODO(Mohammad): Implement fee calculation logic.
            fee
        }
    }
}

