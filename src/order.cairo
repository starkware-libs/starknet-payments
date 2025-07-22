use starknet::ContractAddress;
use starkware_utils::time::time::Timestamp;

#[derive(Drop, Serde, Copy)]
pub struct Order {
    pub salt: felt252,
    pub expiry: Timestamp,
    pub address: ContractAddress,
    pub token_a: ContractAddress,
    pub token_b: ContractAddress,
    pub amount_a: i128,
    pub amount_b: i128,
    pub recipient_addresses: Span<ContractAddress>,
}
