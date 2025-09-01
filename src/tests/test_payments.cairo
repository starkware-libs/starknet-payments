use core::num::traits::Zero;
use openzeppelin::utils::snip12::OffchainMessageHash;
use snforge_std::cheatcodes::events::{EventSpyTrait, EventsFilterTrait};
use snforge_std::{map_entry_address, store};
use starknet::ContractAddress;
use starknet_payments::errors;
use starknet_payments::interface::{
    IPaymentsDispatcher, IPaymentsDispatcherTrait, IPaymentsSafeDispatcher,
    IPaymentsSafeDispatcherTrait,
};
use starkware_utils::signature::stark::HashType;
use starkware_utils::time::time::Timestamp;
use starkware_utils_testing::constants as testing_constants;
use starkware_utils_testing::test_utils::{
    assert_expected_event_emitted, assert_panic_with_error, assert_panic_with_felt_error,
    cheat_caller_address_once,
};
use crate::events;
use crate::order::Order;
use crate::payments::payments::SNIP12MetadataImpl;
use crate::tests::test_utils::*;

fn default_order() -> Order {
    Order {
        salt: 0,
        expiry: Timestamp { seconds: 0 },
        user: testing_constants::DUMMY_ADDRESS,
        sell_token: testing_constants::DUMMY_ADDRESS,
        buy_token: testing_constants::DUMMY_ADDRESS,
        sell_amount: 100,
        buy_amount: 200,
        approved_counterparties: array![].span(),
    }
}

#[test]
fn test_successful_register_token() {
    let contract_address = init_contract_with_roles();
    let dispatcher = IPaymentsDispatcher { contract_address };
    let mut spy = snforge_std::spy_events();

    let token_a: ContractAddress = 'token_a'.try_into().unwrap();
    let token_b: ContractAddress = 'token_b'.try_into().unwrap();

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.register_token(token: token_a);
    assert!(dispatcher.is_token_registered(token: token_a));
    assert!(!dispatcher.is_token_registered(token: token_b));

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.register_token(token: token_b);
    assert!(dispatcher.is_token_registered(token: token_a));
    assert!(dispatcher.is_token_registered(token: token_b));

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.remove_token(token: token_a);
    assert!(!dispatcher.is_token_registered(token: token_a));
    assert!(dispatcher.is_token_registered(token: token_b));

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.remove_token(token: token_b);
    assert!(!dispatcher.is_token_registered(token: token_a));
    assert!(!dispatcher.is_token_registered(token: token_b));

    // Catch the events.
    let events = spy.get_events().emitted_by(contract_address).events;
    let expected_register_token_event = events::TokenRegistered { token: token_a };
    assert_expected_event_emitted(
        spied_event: events[0],
        expected_event: expected_register_token_event,
        expected_event_selector: @selector!("TokenRegistered"),
        expected_event_name: "TokenRegistered",
    );
    let expected_remove_token_event = events::TokenRemoved { token: token_b };
    assert_expected_event_emitted(
        spied_event: events[3],
        expected_event: expected_remove_token_event,
        expected_event_selector: @selector!("TokenRemoved"),
        expected_event_name: "TokenRemoved",
    );
}

#[test]
#[feature("safe_dispatcher")]
fn test_failed_register_token() {
    let contract_address = init_contract_with_roles();
    let dispatcher = IPaymentsSafeDispatcher { contract_address };
    let token: ContractAddress = 'token'.try_into().unwrap();

    let result = dispatcher.remove_token(:token);
    assert_panic_with_error(:result, expected_error: "ONLY_APP_GOVERNOR");

    let result = dispatcher.register_token(:token);
    assert_panic_with_error(:result, expected_error: "ONLY_APP_GOVERNOR");

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    let result = dispatcher.remove_token(:token);
    assert_panic_with_felt_error(:result, expected_error: errors::TOKEN_NOT_REGISTERED);

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.register_token(:token).unwrap();

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    let result = dispatcher.register_token(:token);
    assert_panic_with_felt_error(:result, expected_error: errors::TOKEN_ALREADY_REGISTERED);
}

#[test]
fn test_successful_address_allowlist() {
    let contract_address = init_contract_with_roles();
    let dispatcher = IPaymentsDispatcher { contract_address };
    let mut spy = snforge_std::spy_events();

    let user_a: ContractAddress = 'user_a'.try_into().unwrap();
    let user_b: ContractAddress = 'user_b'.try_into().unwrap();

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.add_to_allowlist(address: user_a);
    assert!(dispatcher.is_allowed(address: user_a));
    assert!(!dispatcher.is_allowed(address: user_b));

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.add_to_allowlist(address: user_b);
    assert!(dispatcher.is_allowed(address: user_a));
    assert!(dispatcher.is_allowed(address: user_b));

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.remove_from_allowlist(address: user_a);
    assert!(!dispatcher.is_allowed(address: user_a));
    assert!(dispatcher.is_allowed(address: user_b));

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.remove_from_allowlist(address: user_b);
    assert!(!dispatcher.is_allowed(address: user_a));
    assert!(!dispatcher.is_allowed(address: user_b));

    // Catch the events.
    let events = spy.get_events().emitted_by(contract_address).events;
    let expected_register_token_event = events::AddressAllowed { address: user_a };
    assert_expected_event_emitted(
        spied_event: events[0],
        expected_event: expected_register_token_event,
        expected_event_selector: @selector!("AddressAllowed"),
        expected_event_name: "AddressAllowed",
    );
    let expected_remove_token_event = events::AddressDisallowed { address: user_b };
    assert_expected_event_emitted(
        spied_event: events[3],
        expected_event: expected_remove_token_event,
        expected_event_selector: @selector!("AddressDisallowed"),
        expected_event_name: "AddressDisallowed",
    );
}

#[test]
#[feature("safe_dispatcher")]
fn test_failed_address_allowlist() {
    let contract_address = init_contract_with_roles();
    let dispatcher = IPaymentsSafeDispatcher { contract_address };
    let user: ContractAddress = 'user'.try_into().unwrap();

    let result = dispatcher.remove_from_allowlist(address: user);
    assert_panic_with_error(:result, expected_error: "ONLY_APP_GOVERNOR");

    let result = dispatcher.add_to_allowlist(address: user);
    assert_panic_with_error(:result, expected_error: "ONLY_APP_GOVERNOR");

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    let result = dispatcher.remove_from_allowlist(address: user);
    assert_panic_with_felt_error(:result, expected_error: errors::UNALLOWED_ADDRESS);

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.add_to_allowlist(address: user).unwrap();

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    let result = dispatcher.add_to_allowlist(address: user);
    assert_panic_with_felt_error(:result, expected_error: errors::ADDRESS_ALREADY_ALLOWED);
}

#[test]
fn test_successful_set_fee() {
    let contract_address = init_contract_with_roles();
    let dispatcher = IPaymentsDispatcher { contract_address };
    let fee_recipient: ContractAddress = 'fee_recipient'.try_into().unwrap();
    let mut spy = snforge_std::spy_events();

    const NEW_FEE: u128 = 1000;

    assert!(dispatcher.get_fee() == constants::FEE);
    assert!(dispatcher.get_fee_recipient() == constants::FEE_RECIPIENT);

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::OPERATOR);
    dispatcher.set_fee(fee: NEW_FEE);

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::OPERATOR);
    dispatcher.set_fee_recipient(recipient: fee_recipient);
    assert!(dispatcher.get_fee() == NEW_FEE);
    assert!(dispatcher.get_fee_recipient() == fee_recipient);

    // Catch the events.
    let events = spy.get_events().emitted_by(contract_address).events;
    let expected_remove_token_event = events::FeeSet { fee: NEW_FEE };
    assert_expected_event_emitted(
        spied_event: events[0],
        expected_event: expected_remove_token_event,
        expected_event_selector: @selector!("FeeSet"),
        expected_event_name: "FeeSet",
    );
    let expected_set_fee_recipient_event = events::FeeRecipientSet {
        old_recipient: constants::FEE_RECIPIENT, new_recipient: fee_recipient,
    };
    assert_expected_event_emitted(
        spied_event: events[1],
        expected_event: expected_set_fee_recipient_event,
        expected_event_selector: @selector!("FeeRecipientSet"),
        expected_event_name: "FeeRecipientSet",
    );
}

#[test]
#[feature("safe_dispatcher")]
fn test_failed_set_fee() {
    let contract_address = init_contract_with_roles();
    let dispatcher = IPaymentsSafeDispatcher { contract_address };
    let fee_recipient: ContractAddress = 'fee_recipient'.try_into().unwrap();

    let result = dispatcher.set_fee(fee: 1000);
    assert_panic_with_error(:result, expected_error: "ONLY_OPERATOR");

    let result = dispatcher.set_fee_recipient(recipient: fee_recipient);
    assert_panic_with_error(:result, expected_error: "ONLY_OPERATOR");

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::OPERATOR);
    let result = dispatcher.set_fee_recipient(recipient: Zero::zero());
    assert_panic_with_felt_error(:result, expected_error: errors::INVALID_ZERO_ADDRESS);

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::OPERATOR);
    let result = dispatcher.set_fee(fee: 1001);
    assert_panic_with_felt_error(:result, expected_error: errors::INVALID_HIGH_FEE);
}


#[test]
fn test_successful_handle_order() {
    let contract_address = init_contract_with_roles();
    let dispatcher = IPaymentsDispatcher { contract_address };
    let user = testing_constants::DUMMY_ADDRESS;
    let mut spy = snforge_std::spy_events();

    let order_1 = Order { sell_amount: 10, ..default_order() };
    let order_2 = Order { salt: 2, sell_amount: 20, ..default_order() };
    let order_3 = Order { salt: 3, sell_amount: 30, ..default_order() };
    let orders = array![order_1, order_2, order_3];
    let mut order_hashes: Array<HashType> = array![];
    for order in orders.span() {
        let message_hash = order.get_message_hash(user);
        order_hashes.append(message_hash);
    }

    for order_hash in order_hashes.span() {
        assert_eq!(dispatcher.get_order_fulfillment(*order_hash), 0);
    }

    // Cancel order 1.
    cheat_caller_address_once(:contract_address, caller_address: testing_constants::OPERATOR);
    dispatcher.cancel_orders(orders: array![*(orders[0])].span());
    assert_eq!(dispatcher.get_order_fulfillment(*(order_hashes[0])), 10);
    for order_hash in order_hashes.span().slice(1, 2) {
        assert_eq!(dispatcher.get_order_fulfillment(*order_hash), 0);
    }

    // Partial fulfill order 2.
    store(
        contract_address,
        map_entry_address(
            selector!("fulfillment"), // storage variable name
            array![*(order_hashes[1])].span() // map key
        ),
        array![11].span(),
    );

    // Partial fulfill order 3.
    store(
        contract_address,
        map_entry_address(selector!("fulfillment"), array![*(order_hashes[2])].span()),
        array![25].span(),
    );

    assert_eq!(dispatcher.get_order_fulfillment(*(order_hashes[0])), 10);
    assert_eq!(dispatcher.get_order_fulfillment(*(order_hashes[1])), 11);
    assert_eq!(dispatcher.get_order_fulfillment(*(order_hashes[2])), 25);

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::OPERATOR);
    dispatcher.cancel_orders(orders: array![*(orders[2])].span());
    assert_eq!(dispatcher.get_order_fulfillment(*(order_hashes[0])), 10);
    assert_eq!(dispatcher.get_order_fulfillment(*(order_hashes[1])), 11);
    assert_eq!(dispatcher.get_order_fulfillment(*(order_hashes[2])), 30);

    // Catch the events.
    let events = spy.get_events().emitted_by(contract_address).events;
    let expected_event = events::OrderCanceled {
        hash: *(order_hashes[0]), user: testing_constants::DUMMY_ADDRESS,
    };
    assert_expected_event_emitted(
        spied_event: events[0],
        expected_event: expected_event,
        expected_event_selector: @selector!("OrderCanceled"),
        expected_event_name: "OrderCanceled",
    );
}

#[test]
#[feature("safe_dispatcher")]
fn test_failed_handle_order() {
    let contract_address = init_contract_with_roles();
    let dispatcher = IPaymentsSafeDispatcher { contract_address };

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::DUMMY_ADDRESS);
    let result = dispatcher.cancel_orders(orders: array![default_order()].span());
    assert_panic_with_error(:result, expected_error: "ONLY_OPERATOR");
}
