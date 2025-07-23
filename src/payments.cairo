#[starknet::contract]
pub mod payments {
    use core::num::traits::{WideMul, Zero};
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
    use starkware_utils::signature::stark::{HashType, Signature};
    use starkware_utils::time::time::Time;
    use crate::errors::{
        INVALID_AMOUNT, INVALID_AMOUNT_RATIO, INVALID_DOWNCAST_AFTER_DIVISION, INVALID_HIGH_FEE,
        INVALID_HIGH_FEE_LIMIT, INVALID_TOKEN_PAIR, INVALID_TRADE_SAME_USER, INVALID_ZERO_ADDRESS,
        INVALID_ZERO_AMOUNT_RATIO, INVALID_ZERO_TOKEN, ORDER_EXPIRED, TOKEN_ALREADY_REGISTERED,
        TOKEN_NOT_REGISTERED, TRANSFER_FAILED, UNALLOWED_ADDRESS,
    };
    use crate::interface::IPayments;
    use crate::order::Order;
    use crate::utils::{is_allowed_addresses, validate_signature};

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
        // Order hash to fulfilled sell amount.
        fulfillment: Map<HashType, u128>,
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
            order_a: Order,
            order_b: Order,
            signature_a: Signature,
            signature_b: Signature,
            actual_sell_amount: u128,
            actual_buy_amount: u128,
        ) {
            self.pausable.assert_not_paused();

            /// Trade validation:

            // Validate orders.
            self._validate_order(order: order_a);
            self._validate_order(order: order_b);

            self._validate_settlement(:order_a, :order_b, :actual_sell_amount, :actual_buy_amount);

            /// Trade execution:

            // Update the fulfillment and validate signature.
            let (prev_seller_fulfilled_amount, order_a_hash) = self
                ._apply_fulfillment(order: order_a, actual_amount: actual_sell_amount);

            // The actual amounts are from `order_a`'s perspective; they're reversed for
            // `order_b`.
            let (prev_buyer_fulfilled_amount, order_b_hash) = self
                ._apply_fulfillment(order: order_b, actual_amount: actual_buy_amount);

            // Signature validation.

            // Validate signatures once.
            if prev_seller_fulfilled_amount.is_zero() {
                validate_signature(
                    signer: order_a.user, hash: order_a_hash, signature: signature_a,
                );
            }

            if prev_buyer_fulfilled_amount.is_zero() {
                validate_signature(
                    signer: order_b.user, hash: order_b_hash, signature: signature_b,
                );
            }

            let sell_token = IERC20Dispatcher { contract_address: order_a.sell_token };
            let buy_token = IERC20Dispatcher { contract_address: order_a.buy_token };

            // Take fees.
            let fee_recipient = self.fee_recipient.read();
            let fee_1 = self._calculate_fee(actual_sell_amount);
            // The actual amounts are from `order_a`'s perspective; they're reversed for
            // `order_b`.
            let fee_2 = self._calculate_fee(actual_buy_amount);
            assert(
                sell_token.transfer_from(order_a.user, fee_recipient, fee_1.into()),
                TRANSFER_FAILED,
            );
            assert(
                buy_token.transfer_from(order_b.user, fee_recipient, fee_2.into()), TRANSFER_FAILED,
            );

            // Transfer the actual amounts.
            assert(
                sell_token
                    .transfer_from(order_a.user, order_b.user, (actual_sell_amount - fee_1).into()),
                TRANSFER_FAILED,
            );
            assert(
                buy_token
                    .transfer_from(order_b.user, order_a.user, (actual_buy_amount - fee_2).into()),
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

        fn cancel_orders(ref self: ContractState, orders: Span<Order>) {
            self.roles.only_operator();

            for order in orders {
                self._cancel_order(order: *order);
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

        fn get_order_fulfillment(self: @ContractState, order_hash: HashType) -> u128 {
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

        fn _apply_fulfillment(
            ref self: ContractState, order: Order, actual_amount: u128,
        ) -> (u128, HashType) {
            let order_hash = order.get_message_hash(signer: order.user);
            let fulfillment_entry = self.fulfillment.entry(order_hash);
            let prev_fulfilled_amount = fulfillment_entry.read();

            let total_amount = prev_fulfilled_amount + actual_amount;
            assert(total_amount <= order.sell_amount, INVALID_AMOUNT);
            fulfillment_entry.write(total_amount);

            (prev_fulfilled_amount, order_hash)
        }

        fn _cancel_order(ref self: ContractState, order: Order) {
            let order_hash = order.get_message_hash(signer: order.user);

            // By setting the fulfillment to the ordered amount, we prevent any future trades.
            self.fulfillment.write(order_hash, order.sell_amount);
        }


        /// Validates that an order is not expired, has a non-zero user, and non-zero sell/buy
        /// amounts.
        fn _validate_order(self: @ContractState, order: Order) {
            assert(order.expiry >= Time::now(), ORDER_EXPIRED);
            assert(order.user.is_non_zero(), INVALID_ZERO_ADDRESS);

            assert(order.sell_amount.is_non_zero(), INVALID_ZERO_AMOUNT_RATIO);
            assert(order.buy_amount.is_non_zero(), INVALID_ZERO_AMOUNT_RATIO);
        }

        /// Validates that two orders are compatible for matching and execution.
        ///
        /// Checks performed:
        /// - orders has valid, non-zero, distinct tokens that are registered.
        /// - The two orders come from different users.
        /// - Token pairs are complementary.
        /// - Each user is allowed by the other’s allowed-addresses list.
        /// - The actual trade amounts satisfy both orders’ price ratios, using
        /// `actual_sell_amount` and `actual_buy_amount` from opposite perspectives.
        fn _validate_settlement(
            self: @ContractState,
            order_a: Order,
            order_b: Order,
            actual_sell_amount: u128,
            actual_buy_amount: u128,
        ) {
            assert(order_a.sell_token.is_non_zero(), INVALID_ZERO_TOKEN);
            assert(order_a.buy_token.is_non_zero(), INVALID_ZERO_TOKEN);
            assert(order_a.sell_token != order_a.buy_token, INVALID_TOKEN_PAIR);

            assert(self.is_token_registered(order_a.sell_token), TOKEN_NOT_REGISTERED);
            assert(self.is_token_registered(order_a.buy_token), TOKEN_NOT_REGISTERED);

            assert(order_a.user != order_b.user, INVALID_TRADE_SAME_USER);

            // Validate the token pair.
            assert(order_a.sell_token == order_b.buy_token, INVALID_TOKEN_PAIR);
            assert(order_a.buy_token == order_b.sell_token, INVALID_TOKEN_PAIR);

            // Validate the amount ratio.
            assert(
                order_a
                    .sell_amount
                    .wide_mul(other: actual_buy_amount) >= order_a
                    .buy_amount
                    .wide_mul(other: actual_sell_amount),
                INVALID_AMOUNT_RATIO,
            );
            // The actual amounts are from `order_a`'s perspective; they're reversed for `order_b`.
            assert(
                order_b
                    .sell_amount
                    .wide_mul(other: actual_sell_amount) >= order_b
                    .buy_amount
                    .wide_mul(other: actual_buy_amount),
                INVALID_AMOUNT_RATIO,
            );

            assert(actual_sell_amount.is_non_zero(), INVALID_ZERO_AMOUNT_RATIO);
            assert(actual_buy_amount.is_non_zero(), INVALID_ZERO_AMOUNT_RATIO);

            // Validate allowed addresses.
            assert(
                is_allowed_addresses(order_b.user, order_a.allowed_addresses), UNALLOWED_ADDRESS,
            );
            assert(
                is_allowed_addresses(order_a.user, order_b.allowed_addresses), UNALLOWED_ADDRESS,
            );
        }


        fn _calculate_fee(self: @ContractState, amount: u128) -> u128 {
            let fee = self.fee.read();

            mul_wide_and_ceil_div(amount, fee, MAX_BASIS_POINTS.into())
                .expect(INVALID_DOWNCAST_AFTER_DIVISION)
        }
    }
}

