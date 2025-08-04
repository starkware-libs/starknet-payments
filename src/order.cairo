use core::hash::{Hash, HashStateExTrait, HashStateTrait};
use core::poseidon::PoseidonTrait;
use openzeppelin::utils::snip12::StructHash;
use starknet::ContractAddress;
use starkware_utils::signature::stark::{HashType, PublicKey};
use starkware_utils::time::time::Timestamp;

#[derive(Drop, Serde, Copy)]
pub struct Order {
    pub salt: felt252,
    pub expiry: Timestamp,
    pub address: ContractAddress,
    pub public_key: PublicKey,
    pub token_a: ContractAddress,
    pub token_b: ContractAddress,
    pub amount_a: i128,
    pub amount_b: i128,
    pub recipient_addresses: Span<ContractAddress>,
}

pub impl HashOrderImpl<S, +HashStateTrait<S>, +Drop<S>> of Hash<Order, S> {
    fn update_state(mut state: S, value: Order) -> S {
        let Order {
            salt,
            expiry,
            address,
            public_key,
            token_a,
            token_b,
            amount_a,
            amount_b,
            recipient_addresses,
        } = value;
        state = state
            .update_with(salt)
            .update_with(expiry)
            .update_with(address)
            .update_with(public_key)
            .update_with(token_a)
            .update_with(token_b)
            .update_with(amount_a)
            .update_with(amount_b)
            .update_with(recipient_addresses.len());
        for elem in recipient_addresses {
            state = state.update_with(*elem);
        }

        state
    }
}

/// selector!(
///   "\"Order\"(
///    \"salt\":\"felt\",
///    \"expiry\":\"Timestamp\",
///    \"address\":\"ContractAddress\",
///    \"public_key\":\"PublicKey\",
///    \"token_a\":\"ContractAddress\",
///    \"token_b\":\"ContractAddress\",
///    \"amount_a\":\"i128\",
///    \"amount_b\":\"i128\",
///    \"recipient_addresses\":\"Span<ContractAddress>\"
///    )
///    \"Timestamp\"(
///    \"seconds\":\"u64\"
///    )
/// );

const ORDER_TYPE_HASH: HashType = 0x169104c1c400388948c9c5c26ec302e41394687a68f73301e33044c88349bd0;

impl StructHashImpl of StructHash<Order> {
    fn hash_struct(self: @Order) -> HashType {
        let hash_state = PoseidonTrait::new();
        hash_state.update_with(ORDER_TYPE_HASH).update_with(*self).finalize()
    }
}

#[cfg(test)]
mod tests {
    use openzeppelin_testing::common::IntoBase16String;
    use super::ORDER_TYPE_HASH;

    #[test]
    fn test_order_type_hash() {
        let expected = selector!(
            "\"Order\"(\"salt\":\"felt\",\"expiry\":\"Timestamp\",\"address\":\"ContractAddress\",\"public_key\":\"PublicKey\",\"token_a\":\"ContractAddress\",\"token_b\":\"ContractAddress\",\"amount_a\":\"i128\",\"amount_b\":\"i128\",\"recipient_addresses\":\"Span<ContractAddress>\")\"Timestamp\"(\"seconds\":\"u64\")",
        );
        assert_eq!(ORDER_TYPE_HASH.into_base_16_string(), expected.into_base_16_string());
    }
}
