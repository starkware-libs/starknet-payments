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
    pub owner: ContractAddress,
    pub public_key: PublicKey,
    pub sell_token: ContractAddress,
    pub buy_token: ContractAddress,
    pub sell_amount: u128,
    pub buy_amount: u128,
    // Addresses the user is willing to trade with. Empty means any address
    pub allowed_addresses: Span<ContractAddress>,
}

pub impl HashOrderImpl<S, +HashStateTrait<S>, +Drop<S>> of Hash<Order, S> {
    fn update_state(mut state: S, value: Order) -> S {
        let Order {
            salt,
            expiry,
            owner,
            public_key,
            sell_token,
            buy_token,
            sell_amount,
            buy_amount,
            allowed_addresses,
        } = value;
        state = state
            .update_with(salt)
            .update_with(expiry)
            .update_with(owner)
            .update_with(public_key)
            .update_with(sell_token)
            .update_with(buy_token)
            .update_with(sell_amount)
            .update_with(buy_amount)
            .update_with(allowed_addresses.len());
        for elem in allowed_addresses {
            state = state.update_with(*elem);
        }

        state
    }
}


/// selector!(
///   "\"Order\"(
///    \"salt\":\"felt\",
///    \"expiry\":\"Timestamp\",
///    \"owner\":\"ContractAddress\",
///    \"public_key\":\"PublicKey\",
///    \"sell_token\":\"ContractAddress\",
///    \"buy_token\":\"ContractAddress\",
///    \"sell_amount\":\"u128\",
///    \"buy_amount\":\"u128\",
///    \"allowed_addresses\":\"Span<ContractAddress>\"
///    )
///    \"Timestamp\"(
///    \"seconds\":\"u64\"
///    )
/// );

const ORDER_TYPE_HASH: HashType = 0x110a09f78c9cd3ca416d13d90e38007ba8bde2f44ae77b5fd037cb9bfb68117;

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
            "\"Order\"(\"salt\":\"felt\",\"expiry\":\"Timestamp\",\"owner\":\"ContractAddress\",\"public_key\":\"PublicKey\",\"sell_token\":\"ContractAddress\",\"buy_token\":\"ContractAddress\",\"sell_amount\":\"u128\",\"buy_amount\":\"u128\",\"allowed_addresses\":\"Span<ContractAddress>\")\"Timestamp\"(\"seconds\":\"u64\")",
        );
        assert_eq!(ORDER_TYPE_HASH.into_base_16_string(), expected.into_base_16_string());
    }
}
