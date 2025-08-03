use starknet::ContractAddress;
use crate::order::Order;

#[derive(Copy, Drop, Debug, Serde, PartialEq, starknet::Store)]
pub enum FulfilledStatus {
    #[default]
    PartialFulfilled: u128,
    Canceled: u128,
    Fulfilled,
}

#[starknet::interface]
pub trait IPayments<TContractState> {
    fn trade(
        ref self: TContractState,
        recipient: ContractAddress,
        order_1: Order,
        order_2: Order,
        signature_1: Span<felt252>,
        signature_2: Span<felt252>,
        actual_amount_a: u128,
        actual_amount_b: u128,
    );

    fn register_token(ref self: TContractState, token: ContractAddress);
    fn remove_token(ref self: TContractState, token: ContractAddress);
    fn is_token_registered(self: @TContractState, token: ContractAddress) -> bool;

    fn cancel_orders(ref self: TContractState, orders: Span<Order>);

    // Setters:

    fn set_fee_limit(ref self: TContractState, fee_limit: u128);
    fn set_fee(ref self: TContractState, fee: u128);
    fn set_fee_recipient(ref self: TContractState, recipient: ContractAddress);

    // Getters:

    fn get_fee_limit(self: @TContractState) -> u128;
    fn get_fee(self: @TContractState) -> u128;
    fn get_fee_recipient(self: @TContractState) -> ContractAddress;

    fn get_order_fulfillment(self: @TContractState, order: Order) -> FulfilledStatus;
}
