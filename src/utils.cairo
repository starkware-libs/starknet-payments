use openzeppelin::account::interface::{ISRC6Dispatcher, ISRC6DispatcherTrait};
use starknet::ContractAddress;
use crate::errors::{INVALID_STARK_SIGNATURE, INVALID_TOKEN_PAIR, UNALLOWED_ADDRESS};
use crate::order::Order;

fn validate_allowed_addresses(maker: ContractAddress, allowed_addresses: Span<ContractAddress>) {
    // Means all addresses are allowed.
    if allowed_addresses.len() == 0 {
        return;
    }

    // check if buyer_order.maker is in seller_order.allowed_addresses.
    let mut found = false;
    for address in allowed_addresses {
        if *address == maker {
            found = true;
            break;
        }
    }

    assert(found, UNALLOWED_ADDRESS);
}

pub fn assert_valid_signature(signer: ContractAddress, hash: felt252, signature: Span<felt252>) {
    let is_valid_signature_felt = ISRC6Dispatcher { contract_address: signer }
        .is_valid_signature(hash, signature.into());

    // Check either 'VALID' or true for backwards compatibility
    let is_valid_signature = is_valid_signature_felt == starknet::VALIDATED
        || is_valid_signature_felt == 1;

    assert(is_valid_signature, INVALID_STARK_SIGNATURE);
}

pub fn validate_match_orders(
    buyer_order: Order, seller_order: Order, actual_sell_amount: u128, actual_buy_amount: u128,
) {
    // Validate the token pair.
    assert(buyer_order.sell_token == seller_order.buy_token, INVALID_TOKEN_PAIR);
    assert(buyer_order.buy_token == seller_order.sell_token, INVALID_TOKEN_PAIR);

    // Validate allowed addresses.
    validate_allowed_addresses(buyer_order.maker, seller_order.allowed_addresses);
    validate_allowed_addresses(seller_order.maker, buyer_order.allowed_addresses);
}

