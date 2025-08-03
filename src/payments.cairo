#[starknet::contract]
pub mod payments {
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::{ContractAddress, get_caller_address};
    use starknet_payments::errors::INVALID_CALLER_ADDRESS;
    use starknet_payments::interface::IPayments;
    use starknet_payments::order::Order;
    use starkware_utils::components::pausable::PausableComponent;
    use starkware_utils::components::replaceability::ReplaceabilityComponent;
    use starkware_utils::components::replaceability::ReplaceabilityComponent::InternalReplaceabilityTrait;
    use starkware_utils::components::roles::RolesComponent;
    use starkware_utils::components::roles::RolesComponent::InternalTrait as RolesInternal;
    use starkware_utils::math::abs::Abs;
    use starkware_utils::signature::stark::HashType;

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
        fee_recipient: ContractAddress,
        fee: u128,
    ) {
        self.roles.initialize(:governance_admin);
        self.replaceability.initialize(:upgrade_delay);
    }

    // TODO(Mohammad): implement the IPayments trait methods.
    #[abi(embed_v0)]
    pub impl PaymentsImpl of IPayments<ContractState> {
        fn trade(
            ref self: ContractState,
            recipient: ContractAddress,
            order_1: Order,
            order_2: Order,
            signature_1: Span<felt252>,
            signature_2: Span<felt252>,
            actual_amount_a: u128,
            actual_amount_b: u128,
        ) {}

        fn add_token(ref self: ContractState, token: ContractAddress) {}
        fn remove_token(ref self: ContractState, token: ContractAddress) {}

        fn cancel_orders(ref self: ContractState, orders: Span<Order>) {
            let caller = get_caller_address();

            for order in orders {
                assert(*order.address == caller, INVALID_CALLER_ADDRESS);

                // TODO(Mohammad): Replace with actual hash computation logic.
                let order_hash: HashType = Default::default();
                self.fulfillment.write(order_hash, order.amount_a.abs());
            }
        }

        // Setters:

        fn set_fee(ref self: ContractState, fee: u128) {}
        fn set_fee_recipient(ref self: ContractState, recipient: ContractAddress) {}

        // Getters:

        fn get_fee(self: @ContractState) -> u128 {
            Default::default()
        }
        fn get_fee_recipient(self: @ContractState) -> ContractAddress {
            'DUMMY_ADDRESS'.try_into().unwrap()
        }

        fn is_order_fulfilled(self: @ContractState, order: Order) -> bool {
            // TODO(Mohammad): Replace with actual hash computation logic.
            let order_hash: HashType = Default::default();
            let fulfilled_amount = self.fulfillment.read(order_hash);
            let ordered_amount = order.amount_a.abs();
            ordered_amount == fulfilled_amount
        }
    }
}

