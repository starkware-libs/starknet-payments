#[starknet::contract]
pub mod payments {
    use core::num::traits::Zero;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
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
    use starkware_utils::signature::stark::HashType;
    use crate::errors::{
        INVALID_HIGH_FEE, INVALID_HIGH_FEE_LIMIT, INVALID_ZERO_ADDRESS, TOKEN_ALREADY_REGISTERED,
        TOKEN_NOT_REGISTERED, TRANSFER_FAILED,
    };
    use crate::interface::IPayments;
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
            order_1: Order,
            order_2: Order,
            signature_1: Span<felt252>,
            signature_2: Span<felt252>,
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
            let fulfillment_entry_1 = self.fulfillment.entry(order_hash_1);
            fulfillment_entry_1.write(fulfillment_entry_1.read() + actual_sell_amount);
            let fulfillment_entry_2 = self.fulfillment.entry(order_hash_2);
            fulfillment_entry_2.write(fulfillment_entry_2.read() + actual_sell_amount);

            let sell_token = IERC20Dispatcher { contract_address: order_1.sell_token };
            let buy_token = IERC20Dispatcher { contract_address: order_1.buy_token };

            // Take fees.
            let fee = self._calculate_fee(actual_sell_amount);
            let fee_recipient = self.fee_recipient.read();
            assert(
                sell_token.transfer_from(order_1.maker, fee_recipient, fee.into()), TRANSFER_FAILED,
            );
            assert(
                sell_token.transfer_from(order_2.maker, fee_recipient, fee.into()), TRANSFER_FAILED,
            );

            // Transfer the actual amounts.
            assert(
                sell_token
                    .transfer_from(order_1.maker, order_2.maker, (actual_sell_amount - fee).into()),
                TRANSFER_FAILED,
            );
            assert(
                buy_token.transfer_from(order_2.maker, order_1.maker, actual_buy_amount.into()),
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

        fn cancel_orders(ref self: ContractState, orders: Span<HashType>) {}

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

        fn is_order_fulfilled(self: @ContractState, order: Order) -> bool {
            Default::default()
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

        fn _validate_order(
            self: @ContractState,
            order: Order,
            signature: Span<felt252>,
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

