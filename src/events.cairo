use starknet::ContractAddress;

#[derive(Debug, Drop, PartialEq, starknet::Event)]
pub struct SetFeeLimit {
    pub fee_limit: u128,
}

#[derive(Debug, Drop, PartialEq, starknet::Event)]
pub struct SetFee {
    pub fee: u128,
}

#[derive(Debug, Drop, PartialEq, starknet::Event)]
pub struct SetFeeRecipient {
    #[key]
    pub old_recipient: ContractAddress,
    #[key]
    pub new_recipient: ContractAddress,
}

#[derive(Debug, Drop, PartialEq, starknet::Event)]
pub struct TokenRegistered {
    #[key]
    pub token: ContractAddress,
}

#[derive(Debug, Drop, PartialEq, starknet::Event)]
pub struct TokenRemoved {
    #[key]
    pub token: ContractAddress,
}

#[derive(Debug, Drop, PartialEq, starknet::Event)]
pub struct Trade {
    #[key]
    pub user_a: ContractAddress,
    #[key]
    pub user_b: ContractAddress,
    #[key]
    pub sell_token: ContractAddress,
    #[key]
    pub buy_token: ContractAddress,
    pub order_a_sell_amount: u128,
    pub order_a_buy_amount: u128,
}

#[derive(Debug, Drop, PartialEq, starknet::Event)]
pub struct OrderCanceled {
    #[key]
    pub user: ContractAddress,
    #[key]
    pub hash: felt252,
}
