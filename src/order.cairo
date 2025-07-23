use starknet::ContractAddress;
use starkware_utils::signature::stark::PublicKey;
use starkware_utils::time::time::Timestamp;

#[derive(Drop, Serde, Copy)]
pub struct Order {
    pub salt: felt252,
    pub expiry: Timestamp,
    pub maker: ContractAddress,
    pub public_key: PublicKey,
    pub sell_token: ContractAddress,
    pub buy_token: ContractAddress,
    pub sell_amount: u128,
    pub buy_amount: u128,
    pub recipient_addresses: Span<ContractAddress>,
}
