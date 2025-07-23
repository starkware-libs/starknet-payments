use starknet::ContractAddress;
use starkware_utils::signature::stark::HashType;
use crate::order::Order;

#[starknet::interface]
pub trait IPayments<TContractState> {
    fn trade(
        ref self: TContractState,
        order_1: Order,
        order_2: Order,
        signature_1: Span<felt252>,
        signature_2: Span<felt252>,
        // Approve execution parameters:
        nonce_1: felt252,
        execute_after_1: u64,
        execute_before_1: u64,
        nonce_2: felt252,
        execute_after_2: u64,
        execute_before_2: u64,
        approve_signature_1: Span<felt252>,
        approve_signature_2: Span<felt252>,
        actual_sell_amount: u128,
        actual_buy_amount: u128,
    );

    fn register_token(ref self: TContractState, token: ContractAddress);
    fn remove_token(ref self: TContractState, token: ContractAddress);
    fn is_token_registered(self: @TContractState, token: ContractAddress) -> bool;

    fn cancel_orders(ref self: TContractState, orders: Span<HashType>);

    // Setters:

    fn set_fee_limit(ref self: TContractState, fee_limit: u128);
    fn set_fee(ref self: TContractState, fee: u128);
    fn set_fee_recipient(ref self: TContractState, recipient: ContractAddress);

    // Getters:

    fn get_fee_limit(self: @TContractState) -> u128;
    fn get_fee(self: @TContractState) -> u128;
    fn get_fee_recipient(self: @TContractState) -> ContractAddress;

    fn is_order_fulfilled(self: @TContractState, order: Order) -> bool;
}
