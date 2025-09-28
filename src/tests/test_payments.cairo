use core::num::traits::Zero;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::utils::snip12::OffchainMessageHash;
use snforge_std::cheatcodes::events::{EventSpyTrait, EventsFilterTrait};
use snforge_std::signature::stark_curve::{StarkCurveKeyPairImpl, StarkCurveSignerImpl};
use snforge_std::{map_entry_address, start_cheat_block_timestamp_global, store};
use starknet::ContractAddress;
use starknet_payments::errors;
use starknet_payments::interface::{
    IPaymentsDispatcher, IPaymentsDispatcherTrait, IPaymentsSafeDispatcher,
    IPaymentsSafeDispatcherTrait,
};
use starkware_utils::components::pausable::interface::{
    IPausableDispatcher, IPausableDispatcherTrait,
};
use starkware_utils::constants::MAX_U128;
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
fn test_successful_set_dust_limit() {
    let contract_address = init_contract_with_roles();
    let dispatcher = IPaymentsDispatcher { contract_address };
    let mut spy = snforge_std::spy_events();

    const NEW_DUST_LIMIT: u128 = 20000;

    assert!(dispatcher.get_dust_limit() == constants::DUST_LIMIT);

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::OPERATOR);
    dispatcher.set_dust_limit(dust_limit: NEW_DUST_LIMIT);

    assert!(dispatcher.get_dust_limit() == NEW_DUST_LIMIT);

    // Catch the events.
    let events = spy.get_events().emitted_by(contract_address).events;
    let expected_remove_token_event = events::DustLimitSet { dust_limit: NEW_DUST_LIMIT };
    assert_expected_event_emitted(
        spied_event: events[0],
        expected_event: expected_remove_token_event,
        expected_event_selector: @selector!("DustLimitSet"),
        expected_event_name: "DustLimitSet",
    );
}

#[test]
#[feature("safe_dispatcher")]
fn test_failed_set_dust_limit() {
    let contract_address = init_contract_with_roles();
    let dispatcher = IPaymentsSafeDispatcher { contract_address };

    let result = dispatcher.set_dust_limit(dust_limit: 1000);
    assert_panic_with_error(:result, expected_error: "ONLY_OPERATOR");

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::OPERATOR);
    let result = dispatcher.set_dust_limit(dust_limit: Zero::zero());
    assert_panic_with_felt_error(:result, expected_error: errors::INVALID_ZERO_AMOUNT);
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


#[test]
#[feature("safe_dispatcher")]
fn test_invalid_orders() {
    // Setup:

    let (contract_address, token_a, token_b, user_a, user_b, _, _) = test_setup(
        initial_balance: constants::INITIAL_BALANCE,
    );
    let dispatcher = IPaymentsSafeDispatcher { contract_address };

    // Add tokens.
    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.register_token(token: token_a).unwrap();
    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.register_token(token: token_b).unwrap();

    let dummy_user: ContractAddress = Zero::zero();
    let dummy_token: ContractAddress = Zero::zero();
    let unregistered_token: ContractAddress = 'UNREGISTERED_TOKEN'.try_into().unwrap();
    let empty_signature = array![].span();

    let order_a = Order {
        salt: 1,
        expiry: Timestamp { seconds: 100 },
        user: user_a,
        sell_token: token_a,
        buy_token: token_b,
        sell_amount: 1000000,
        buy_amount: 10000,
        approved_counterparties: array![].span(),
    };
    let order_b = Order {
        user: user_b,
        sell_token: token_b,
        buy_token: token_a,
        sell_amount: 10000,
        buy_amount: 1000000,
        approved_counterparties: array![user_a].span(),
        ..order_a,
    };

    // Test scenario 1: Order with unallowed address.

    let result = dispatcher
        .trade(
            :order_a,
            :order_b,
            signature_a: empty_signature,
            signature_b: empty_signature,
            order_a_actual_sell_amount: 1000000,
            order_a_actual_buy_amount: 10000,
        );
    assert_panic_with_felt_error(:result, expected_error: errors::UNALLOWED_ADDRESS);

    // Add users to allowlist.
    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.add_to_allowlist(address: user_a).unwrap();
    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.add_to_allowlist(address: user_b).unwrap();

    // Test scenario 2: Order with same tokens.

    let order_a = Order { buy_token: token_a, ..order_a };
    let result = dispatcher
        .trade(
            :order_a,
            :order_b,
            signature_a: empty_signature,
            signature_b: empty_signature,
            order_a_actual_sell_amount: 1000000,
            order_a_actual_buy_amount: 10000,
        );
    assert_panic_with_felt_error(:result, expected_error: errors::INVALID_TOKEN_PAIR);

    // Test scenario 3: Order with zero token.

    let order_a = Order { buy_token: dummy_token, ..order_a };
    let order_b = Order { sell_token: dummy_token, ..order_b };
    let result = dispatcher
        .trade(
            :order_a,
            :order_b,
            signature_a: empty_signature,
            signature_b: empty_signature,
            order_a_actual_sell_amount: 1000000,
            order_a_actual_buy_amount: 10000,
        );
    assert_panic_with_felt_error(:result, expected_error: errors::INVALID_ZERO_TOKEN);

    // Test scenario 4: Order with unregistered tokens.

    let order_a = Order { buy_token: unregistered_token, ..order_a };
    let order_b = Order { sell_token: unregistered_token, ..order_b };
    let result = dispatcher
        .trade(
            :order_a,
            :order_b,
            signature_a: empty_signature,
            signature_b: empty_signature,
            order_a_actual_sell_amount: 1000000,
            order_a_actual_buy_amount: 10000,
        );
    assert_panic_with_felt_error(:result, expected_error: errors::TOKEN_NOT_REGISTERED);

    // Test scenario 5: Orders with different tokens.

    let order_a = Order { buy_token: token_b, ..order_a };
    let result = dispatcher
        .trade(
            :order_a,
            :order_b,
            signature_a: empty_signature,
            signature_b: empty_signature,
            order_a_actual_sell_amount: 1000000,
            order_a_actual_buy_amount: 10000,
        );
    assert_panic_with_felt_error(:result, expected_error: errors::INVALID_TOKEN_PAIR);

    // Test scenario 6: Orders with same tokens.

    let order_a = Order { buy_token: token_a, ..order_a };
    let order_b = Order { sell_token: token_a, ..order_b };
    let result = dispatcher
        .trade(
            :order_a,
            :order_b,
            signature_a: empty_signature,
            signature_b: empty_signature,
            order_a_actual_sell_amount: 1000000,
            order_a_actual_buy_amount: 10000,
        );
    assert_panic_with_felt_error(:result, expected_error: errors::INVALID_TOKEN_PAIR);

    // Test scenario 7: Order with zero address.

    let order_a = Order { user: dummy_user, buy_token: token_b, ..order_a };
    let order_b = Order { sell_token: token_b, ..order_b };
    let result = dispatcher
        .trade(
            :order_a,
            :order_b,
            signature_a: empty_signature,
            signature_b: empty_signature,
            order_a_actual_sell_amount: 1000000,
            order_a_actual_buy_amount: 10000,
        );
    assert_panic_with_felt_error(:result, expected_error: errors::INVALID_ZERO_ADDRESS);

    // Test scenario 8: Orders with same addresses.

    let order_a = Order { user: user_b, ..order_a };
    let result = dispatcher
        .trade(
            :order_a,
            :order_b,
            signature_a: empty_signature,
            signature_b: empty_signature,
            order_a_actual_sell_amount: 1000000,
            order_a_actual_buy_amount: 10000,
        );
    assert_panic_with_felt_error(:result, expected_error: errors::INVALID_TRADE_SAME_USER);

    // Test scenario 9: Order with zero sell amount.

    let order_a = Order { user: user_a, sell_amount: 0, ..order_a };
    let result = dispatcher
        .trade(
            :order_a,
            :order_b,
            signature_a: empty_signature,
            signature_b: empty_signature,
            order_a_actual_sell_amount: 1000000,
            order_a_actual_buy_amount: 10000,
        );
    assert_panic_with_felt_error(:result, expected_error: errors::INVALID_ZERO_AMOUNT);

    // Test scenario 10: Order with zero buy amount.

    let order_a = Order { sell_amount: 1000000, ..order_a };
    let order_b = Order { buy_amount: 0, ..order_b };
    let result = dispatcher
        .trade(
            :order_a,
            :order_b,
            signature_a: empty_signature,
            signature_b: empty_signature,
            order_a_actual_sell_amount: 1000000,
            order_a_actual_buy_amount: 10000,
        );
    assert_panic_with_felt_error(:result, expected_error: errors::INVALID_ZERO_AMOUNT);

    // Test scenario 11: Trade with zero actual sell amount.

    let order_b = Order { buy_amount: 1000000, ..order_b };
    let result = dispatcher
        .trade(
            :order_a,
            :order_b,
            signature_a: empty_signature,
            signature_b: empty_signature,
            order_a_actual_sell_amount: 0,
            order_a_actual_buy_amount: 1,
        );
    assert_panic_with_felt_error(:result, expected_error: errors::INVALID_AMOUNT_RATIO);

    // Test scenario 12: Trade with actual buy amount below dust.

    let result = dispatcher
        .trade(
            :order_a,
            :order_b,
            signature_a: empty_signature,
            signature_b: empty_signature,
            order_a_actual_sell_amount: 100000,
            order_a_actual_buy_amount: 1000,
        );
    assert_panic_with_felt_error(:result, expected_error: errors::INVALID_AMOUNT_BELOW_DUST_LIMIT);

    // Test scenario 13: Orders with expired timestamps.

    start_cheat_block_timestamp_global(block_timestamp: 101);
    let result = dispatcher
        .trade(
            :order_a,
            :order_b,
            signature_a: empty_signature,
            signature_b: empty_signature,
            order_a_actual_sell_amount: 1000000,
            order_a_actual_buy_amount: 10000,
        );
    assert_panic_with_felt_error(:result, expected_error: errors::ORDER_EXPIRED);

    // Test scenario 14: Order with unapproved counterparty.

    let order_a = Order {
        expiry: Timestamp { seconds: 101 },
        approved_counterparties: array![dummy_user, user_a].span(),
        ..order_a,
    };
    let order_b = Order { expiry: Timestamp { seconds: 101 }, ..order_b };
    let result = dispatcher
        .trade(
            :order_a,
            :order_b,
            signature_a: empty_signature,
            signature_b: empty_signature,
            order_a_actual_sell_amount: 1000000,
            order_a_actual_buy_amount: 10000,
        );
    assert_panic_with_felt_error(:result, expected_error: errors::UNAPPROVED_COUNTERPARTY);
}

#[test]
#[feature("safe_dispatcher")]
fn test_invalid_trade_scenarios() {
    // Setup:
    let (contract_address, token_a, token_b, user_a, user_b, key_pair_a, key_pair_b) = test_setup(
        initial_balance: constants::INITIAL_BALANCE,
    );
    let dispatcher = IPaymentsSafeDispatcher { contract_address };

    // Add tokens.
    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.register_token(token: token_a).unwrap();
    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.register_token(token: token_b).unwrap();

    // Add users to allowlist.
    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.add_to_allowlist(address: user_a).unwrap();
    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.add_to_allowlist(address: user_b).unwrap();

    let order_a = Order {
        salt: 1,
        expiry: Timestamp { seconds: 100 },
        user: user_a,
        sell_token: token_a,
        buy_token: token_b,
        sell_amount: 1000000,
        buy_amount: 10000,
        approved_counterparties: array![].span(),
    };

    let order_b = Order {
        user: user_b,
        sell_token: token_b,
        buy_token: token_a,
        sell_amount: 10000,
        buy_amount: 1000000,
        approved_counterparties: array![user_a].span(),
        ..order_a,
    };

    let message_hash_a = order_a.get_message_hash(user_a);
    let (r, s) = key_pair_a.sign(message_hash_a).unwrap();
    let signature_a = array![r, s].span();

    let message_hash_b = order_b.get_message_hash(user_b);
    let (r, s) = key_pair_b.sign(message_hash_b).unwrap();
    let signature_b = array![r, s].span();

    // Approve tokens:
    let token_a_dispatcher = IERC20Dispatcher { contract_address: token_a };
    cheat_caller_address_once(token_a, caller_address: user_a);
    token_a_dispatcher.approve(spender: contract_address, amount: 100000000);

    let token_b_dispatcher = IERC20Dispatcher { contract_address: token_b };
    cheat_caller_address_once(token_b, caller_address: user_b);
    token_b_dispatcher.approve(spender: contract_address, amount: 100000000);

    // Test scenario 1: Actual amounts above ordered.

    let result = dispatcher
        .trade(
            :order_a,
            :order_b,
            :signature_a,
            :signature_b,
            order_a_actual_sell_amount: 2000000,
            order_a_actual_buy_amount: 20000,
        );
    assert_panic_with_felt_error(:result, expected_error: errors::INVALID_AMOUNT_TOO_LARGE);

    // Test scenario 2: High buy amount.

    let result = dispatcher
        .trade(
            :order_a,
            :order_b,
            :signature_a,
            :signature_b,
            order_a_actual_sell_amount: 1000000,
            order_a_actual_buy_amount: 100000,
        );
    assert_panic_with_felt_error(:result, expected_error: errors::INVALID_AMOUNT_RATIO);

    // Test scenario 3: Low sell amount.

    let result = dispatcher
        .trade(
            :order_a,
            :order_b,
            :signature_a,
            :signature_b,
            order_a_actual_sell_amount: 900000,
            order_a_actual_buy_amount: 10000,
        );
    assert_panic_with_felt_error(:result, expected_error: errors::INVALID_AMOUNT_RATIO);

    // Test scenario 4: Fulfilled order.

    dispatcher
        .trade(
            :order_a,
            :order_b,
            :signature_a,
            :signature_b,
            order_a_actual_sell_amount: 1000000,
            order_a_actual_buy_amount: 10000,
        )
        .unwrap();

    let result = dispatcher
        .trade(
            :order_a,
            :order_b,
            :signature_a,
            :signature_b,
            order_a_actual_sell_amount: 1000000,
            order_a_actual_buy_amount: 10000,
        );
    assert_panic_with_felt_error(:result, expected_error: errors::INVALID_AMOUNT_TOO_LARGE);

    // Test scenario 5: Canceled order.

    let order_a = Order { salt: 2, ..order_a };
    let order_b = Order { salt: 2, ..order_b };

    let message_hash_a = order_a.get_message_hash(user_a);
    let (r, s) = key_pair_a.sign(message_hash_a).unwrap();
    let signature_a = array![r, s].span();

    let message_hash_b = order_b.get_message_hash(user_b);
    let (r, s) = key_pair_b.sign(message_hash_b).unwrap();
    let signature_b = array![r, s].span();

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::OPERATOR);
    dispatcher.cancel_orders(orders: array![order_a].span()).unwrap();

    let result = dispatcher
        .trade(
            :order_a,
            :order_b,
            :signature_a,
            :signature_b,
            order_a_actual_sell_amount: 1000000,
            order_a_actual_buy_amount: 10000,
        );
    assert_panic_with_felt_error(:result, expected_error: errors::INVALID_AMOUNT_TOO_LARGE);

    // Test scenario 6: Paused system.

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::SECURITY_AGENT);
    IPausableDispatcher { contract_address }.pause();

    let result = dispatcher
        .trade(
            :order_a,
            :order_b,
            :signature_a,
            :signature_b,
            order_a_actual_sell_amount: 1000000,
            order_a_actual_buy_amount: 10000,
        );
    assert_panic_with_felt_error(:result, expected_error: 'PAUSED');

    // Test scenario 7: Invalid signature.

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::SECURITY_ADMIN);
    IPausableDispatcher { contract_address }.unpause();

    let order_a = Order { salt: 3, ..order_a };
    let message_hash_a = order_a.get_message_hash(user_a);
    let (r, s) = key_pair_a.sign(message_hash_a).unwrap();
    let signature_a = array![r, s].span();

    let result = dispatcher
        .trade(
            :order_a,
            :order_b,
            :signature_a,
            signature_b: signature_a, // Invalid signature.
            order_a_actual_sell_amount: 1000000,
            order_a_actual_buy_amount: 10000,
        );
    assert_panic_with_felt_error(:result, expected_error: errors::INVALID_STARK_SIGNATURE);
}

#[test]
fn test_successful_trade() {
    // Setup:
    let (contract_address, token_a, token_b, user_a, user_b, key_pair_a, key_pair_b) = test_setup(
        initial_balance: constants::INITIAL_BALANCE,
    );
    let dispatcher = IPaymentsDispatcher { contract_address };
    let mut spy = snforge_std::spy_events();

    // Add tokens.
    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.register_token(token: token_a);
    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.register_token(token: token_b);

    // Add users to allowlist.
    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.add_to_allowlist(address: user_a);
    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.add_to_allowlist(address: user_b);

    let order_a = Order {
        salt: 1,
        expiry: Timestamp { seconds: 100 },
        user: user_a,
        sell_token: token_a,
        buy_token: token_b,
        sell_amount: 100000000,
        buy_amount: 10000000,
        approved_counterparties: array![].span(),
    };

    let order_b = Order {
        user: user_b,
        sell_token: token_b,
        buy_token: token_a,
        sell_amount: 90000000,
        buy_amount: 80000000,
        approved_counterparties: array![user_a].span(),
        ..order_a,
    };

    let message_hash_a = order_a.get_message_hash(user_a);
    let (r, s) = key_pair_a.sign(message_hash_a).unwrap();
    let signature_a = array![r, s].span();

    let message_hash_b = order_b.get_message_hash(user_b);
    let (r, s) = key_pair_b.sign(message_hash_b).unwrap();
    let signature_b = array![r, s].span();

    // Approve tokens:
    let token_a_dispatcher = IERC20Dispatcher { contract_address: token_a };
    cheat_caller_address_once(token_a, caller_address: user_a);
    token_a_dispatcher.approve(spender: contract_address, amount: 100000000);

    let token_b_dispatcher = IERC20Dispatcher { contract_address: token_b };
    cheat_caller_address_once(token_b, caller_address: user_b);
    token_b_dispatcher.approve(spender: contract_address, amount: 100000000);

    // Test:
    // 8000/900 <= 7560/850 <= 10000/1000
    dispatcher
        .trade(
            :order_a,
            :order_b,
            :signature_a,
            :signature_b,
            order_a_actual_sell_amount: 75600000,
            order_a_actual_buy_amount: 8500000,
        );

    // Checks:
    assert_eq!(token_a_dispatcher.balance_of(user_a), 24400000);
    assert_eq!(token_a_dispatcher.balance_of(user_b), 74844000);
    assert_eq!(token_a_dispatcher.balance_of(constants::FEE_RECIPIENT), 756000);

    assert_eq!(token_b_dispatcher.balance_of(user_a), 8415000);
    assert_eq!(token_b_dispatcher.balance_of(user_b), 91500000);
    assert_eq!(token_b_dispatcher.balance_of(constants::FEE_RECIPIENT), 85000);

    // Catch the events.
    let events = spy.get_events().emitted_by(contract_address).events;
    let expected_event = events::TradeExecuted {
        user_a,
        user_b,
        sell_token: token_a,
        buy_token: token_b,
        order_a_sell_amount: 75600000,
        order_a_buy_amount: 8500000,
        fee_a: 756000,
        fee_b: 85000,
    };
    assert_expected_event_emitted(
        spied_event: events[4],
        expected_event: expected_event,
        expected_event_selector: @selector!("TradeExecuted"),
        expected_event_name: "TradeExecuted",
    );
}

#[test]
fn test_successful_trade_large_numbers() {
    // Setup:
    let (contract_address, token_a, token_b, user_a, user_b, key_pair_a, key_pair_b) = test_setup(
        initial_balance: MAX_U128.into(),
    );
    let dispatcher = IPaymentsDispatcher { contract_address };

    // Add tokens.
    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.register_token(token: token_a);
    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.register_token(token: token_b);

    // Add users to allowlist.
    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.add_to_allowlist(address: user_a);
    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.add_to_allowlist(address: user_b);

    let order_a = Order {
        salt: 1,
        expiry: Timestamp { seconds: 100 },
        user: user_a,
        sell_token: token_a,
        buy_token: token_b,
        sell_amount: MAX_U128,
        buy_amount: MAX_U128,
        approved_counterparties: array![user_b].span(),
    };

    let order_b = Order {
        user: user_b,
        sell_token: token_b,
        buy_token: token_a,
        sell_amount: MAX_U128,
        buy_amount: MAX_U128,
        approved_counterparties: array![user_a].span(),
        ..order_a,
    };

    let message_hash_a = order_a.get_message_hash(user_a);
    let (r, s) = key_pair_a.sign(message_hash_a).unwrap();
    let signature_a = array![r, s].span();

    let message_hash_b = order_b.get_message_hash(user_b);
    let (r, s) = key_pair_b.sign(message_hash_b).unwrap();
    let signature_b = array![r, s].span();

    // Approve tokens:
    let token_a_dispatcher = IERC20Dispatcher { contract_address: token_a };
    cheat_caller_address_once(token_a, caller_address: user_a);
    token_a_dispatcher.approve(spender: contract_address, amount: MAX_U128.into());

    let token_b_dispatcher = IERC20Dispatcher { contract_address: token_b };
    cheat_caller_address_once(token_b, caller_address: user_b);
    token_b_dispatcher.approve(spender: contract_address, amount: MAX_U128.into());

    // Test:
    dispatcher
        .trade(
            :order_a,
            :order_b,
            :signature_a,
            :signature_b,
            order_a_actual_sell_amount: MAX_U128,
            order_a_actual_buy_amount: MAX_U128,
        );

    // Checks:
    // Plus 1 for rounding up.
    let fee: u256 = (MAX_U128 / 100 + 1).into();
    assert_eq!(token_a_dispatcher.balance_of(user_a), 0);
    assert_eq!(token_a_dispatcher.balance_of(user_b), MAX_U128.into() - fee);
    assert_eq!(token_a_dispatcher.balance_of(constants::FEE_RECIPIENT), fee);

    assert_eq!(token_b_dispatcher.balance_of(user_a), MAX_U128.into() - fee);
    assert_eq!(token_b_dispatcher.balance_of(user_b), 0);
    assert_eq!(token_b_dispatcher.balance_of(constants::FEE_RECIPIENT), fee);
}

#[test]
fn test_successful_flow() {
    // Setup:
    let (contract_address, token_a, token_b, user_a, user_b, key_pair_a, key_pair_b) = test_setup(
        initial_balance: constants::INITIAL_BALANCE,
    );
    let dispatcher = IPaymentsDispatcher { contract_address };

    // Add tokens.
    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.register_token(token: token_a);
    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.register_token(token: token_b);

    // Add users to allowlist.
    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.add_to_allowlist(address: user_a);
    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.add_to_allowlist(address: user_b);

    // Set fee:
    cheat_caller_address_once(:contract_address, caller_address: testing_constants::OPERATOR);
    dispatcher.set_fee(fee: 900); // 9%, in this case it would be rounded to 10%.

    let order_a = Order {
        salt: 1,
        expiry: Timestamp { seconds: 100 },
        user: user_a,
        sell_token: token_a,
        buy_token: token_b,
        sell_amount: 1000000,
        buy_amount: 100000,
        approved_counterparties: array![].span(),
    };

    let order_b = Order {
        user: user_b,
        sell_token: token_b,
        buy_token: token_a,
        sell_amount: 50000,
        buy_amount: 500000,
        approved_counterparties: array![user_a].span(),
        ..order_a,
    };

    let message_hash_a = order_a.get_message_hash(user_a);
    let (r, s) = key_pair_a.sign(message_hash_a).unwrap();
    let signature_a = array![r, s].span();

    let message_hash_b = order_b.get_message_hash(user_b);
    let (r, s) = key_pair_b.sign(message_hash_b).unwrap();
    let signature_b = array![r, s].span();

    // Approve tokens:
    let token_a_dispatcher = IERC20Dispatcher { contract_address: token_a };
    cheat_caller_address_once(token_a, caller_address: user_a);
    token_a_dispatcher.approve(spender: contract_address, amount: 10000000);

    let token_b_dispatcher = IERC20Dispatcher { contract_address: token_b };
    cheat_caller_address_once(token_b, caller_address: user_b);
    token_b_dispatcher.approve(spender: contract_address, amount: 10000000);

    // Stage 1:

    // Test:
    dispatcher
        .trade(
            :order_a,
            :order_b,
            :signature_a,
            :signature_b,
            order_a_actual_sell_amount: 500000,
            order_a_actual_buy_amount: 50000,
        );

    // Checks:
    assert_eq!(token_a_dispatcher.balance_of(user_a), 99500000);
    assert_eq!(token_a_dispatcher.balance_of(user_b), 455000);
    assert_eq!(token_a_dispatcher.balance_of(constants::FEE_RECIPIENT), 45000);

    assert_eq!(token_b_dispatcher.balance_of(user_a), 45500);
    assert_eq!(token_b_dispatcher.balance_of(user_b), 99950000);
    assert_eq!(token_b_dispatcher.balance_of(constants::FEE_RECIPIENT), 4500);

    assert_eq!(dispatcher.get_order_fulfillment(message_hash_a), 500000);
    assert_eq!(dispatcher.get_order_fulfillment(message_hash_b), 50000);

    // Stage 2:

    let new_fee_recipient: ContractAddress = 'NEW_FEE_RECIPIENT'.try_into().unwrap();
    cheat_caller_address_once(:contract_address, caller_address: testing_constants::OPERATOR);
    dispatcher.set_fee_recipient(recipient: new_fee_recipient);

    let order_b = Order { salt: 2, ..order_b };
    let message_hash_b = order_b.get_message_hash(user_b);
    let (r, s) = key_pair_b.sign(message_hash_b).unwrap();
    let signature_b = array![r, s].span();

    dispatcher
        .trade(
            :order_a,
            :order_b,
            :signature_a,
            :signature_b,
            order_a_actual_sell_amount: 500000,
            order_a_actual_buy_amount: 50000,
        );

    // Checks:
    assert_eq!(token_a_dispatcher.balance_of(user_a), 99000000);
    assert_eq!(token_a_dispatcher.balance_of(user_b), 910000);
    assert_eq!(token_a_dispatcher.balance_of(constants::FEE_RECIPIENT), 45000);
    assert_eq!(token_a_dispatcher.balance_of(new_fee_recipient), 45000);

    assert_eq!(token_b_dispatcher.balance_of(user_a), 91000);
    assert_eq!(token_b_dispatcher.balance_of(user_b), 99900000);
    assert_eq!(token_b_dispatcher.balance_of(constants::FEE_RECIPIENT), 4500);
    assert_eq!(token_b_dispatcher.balance_of(new_fee_recipient), 4500);

    assert_eq!(dispatcher.get_order_fulfillment(message_hash_a), 1000000);
    assert_eq!(dispatcher.get_order_fulfillment(message_hash_b), 50000);
}
