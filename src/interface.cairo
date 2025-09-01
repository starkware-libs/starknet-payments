use starknet::ContractAddress;
use starkware_utils::signature::stark::{HashType, Signature};
use crate::order::Order;

#[starknet::interface]
pub trait IPayments<TContractState> {
    fn trade(
        ref self: TContractState,
        order_a: Order,
        order_b: Order,
        signature_a: Signature,
        signature_b: Signature,
        order_a_actual_sell_amount: u128,
        order_a_actual_buy_amount: u128,
    );

    fn register_token(ref self: TContractState, token: ContractAddress);
    fn remove_token(ref self: TContractState, token: ContractAddress);
    fn is_token_registered(self: @TContractState, token: ContractAddress) -> bool;

    fn whitelist_address(ref self: TContractState, address: ContractAddress);
    fn remove_from_whitelist(ref self: TContractState, address: ContractAddress);
    fn is_whitelisted(self: @TContractState, address: ContractAddress) -> bool;

    fn cancel_orders(ref self: TContractState, orders: Span<Order>);

    // Setters:

    fn set_fee(ref self: TContractState, fee: u128);
    fn set_fee_recipient(ref self: TContractState, recipient: ContractAddress);

    // Getters:

    fn get_fee_limit(self: @TContractState) -> u128;
    fn get_fee(self: @TContractState) -> u128;
    fn get_fee_recipient(self: @TContractState) -> ContractAddress;

    fn get_order_fulfillment(self: @TContractState, order_hash: HashType) -> u128;
}
