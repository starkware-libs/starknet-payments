use starknet::ContractAddress;

pub const INVALID_AMOUNT_RATIO: felt252 = 'INVALID_AMOUNT_RATIO';
pub const INVALID_AMOUNT_TOO_LARGE: felt252 = 'INVALID_AMOUNT_TOO_LARGE';
pub const INVALID_DOWNCAST_AFTER_DIVISION: felt252 = 'INVALID_DOWNCAST_AFTER_DIVISION';
pub const INVALID_HIGH_FEE: felt252 = 'INVALID_HIGH_FEE';
pub const INVALID_HIGH_FEE_LIMIT: felt252 = 'INVALID_HIGH_FEE_LIMIT';
pub const INVALID_STARK_SIGNATURE: felt252 = 'INVALID_STARK_SIGNATURE';
pub const INVALID_TOKEN_PAIR: felt252 = 'INVALID_TOKEN_PAIR';
pub const INVALID_TRADE_SAME_USER: felt252 = 'INVALID_TRADE_SAME_USER';
pub const INVALID_ZERO_ADDRESS: felt252 = 'INVALID_ZERO_ADDRESS';
pub const INVALID_ZERO_AMOUNT: felt252 = 'INVALID_ZERO_AMOUNT';
pub const INVALID_ZERO_TOKEN: felt252 = 'INVALID_ZERO_TOKEN';
pub const ORDER_EXPIRED: felt252 = 'ORDER_EXPIRED';
pub const TOKEN_ALREADY_REGISTERED: felt252 = 'TOKEN_ALREADY_REGISTERED';
pub const TOKEN_NOT_REGISTERED: felt252 = 'TOKEN_NOT_REGISTERED';
pub const UNALLOWED_ADDRESS: felt252 = 'UNALLOWED_ADDRESS';

pub fn transfer_failed_error(
    token: ContractAddress, sender: ContractAddress, amount: u128,
) -> ByteArray {
    format!("TRANSFER_FAILED token: {:?}, sender: {:?}, amount: {:?}", token, sender, amount)
}
