use core::num::traits::Zero;
use snforge_std::{map_entry_address, store};
use starknet::ContractAddress;
use starknet_payments::errors;
use starknet_payments::interface::{
    IPaymentsDispatcher, IPaymentsDispatcherTrait, IPaymentsSafeDispatcher,
    IPaymentsSafeDispatcherTrait,
};
use starkware_utils::time::time::Timestamp;
use starkware_utils_testing::constants as testing_constants;
use starkware_utils_testing::test_utils::{
    assert_panic_with_error, assert_panic_with_felt_error, cheat_caller_address_once,
};
use crate::order::Order;
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
        allowed_addresses: array![].span(),
    }
}

#[test]
fn test_successful_register_token() {
    let contract_address = init_contract_with_roles();
    let dispatcher = IPaymentsDispatcher { contract_address };

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
fn test_successful_set_fee() {
    let contract_address = init_contract_with_roles();
    let dispatcher = IPaymentsDispatcher { contract_address };
    let fee_recipient: ContractAddress = 'fee_recipient'.try_into().unwrap();

    assert!(dispatcher.get_fee() == constants::FEE);
    assert!(dispatcher.get_fee_recipient() == constants::FEE_RECIPIENT);

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.set_fee_limit(fee_limit: 2000);

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::OPERATOR);
    dispatcher.set_fee(fee: 1500);

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::OPERATOR);
    dispatcher.set_fee_recipient(recipient: fee_recipient);
    assert!(dispatcher.get_fee() == 1500);
    assert!(dispatcher.get_fee_recipient() == fee_recipient);
}

#[test]
#[feature("safe_dispatcher")]
fn test_failed_set_fee() {
    let contract_address = init_contract_with_roles();
    let dispatcher = IPaymentsSafeDispatcher { contract_address };
    let fee_recipient: ContractAddress = 'fee_recipient'.try_into().unwrap();

    let result = dispatcher.set_fee_limit(fee_limit: 10000);
    assert_panic_with_error(:result, expected_error: "ONLY_APP_GOVERNOR");

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

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    let result = dispatcher.set_fee_limit(fee_limit: 10001);
    assert_panic_with_felt_error(:result, expected_error: errors::INVALID_HIGH_FEE_LIMIT);
}


#[test]
fn test_successful_handle_order() {
    let contract_address = init_contract_with_roles();
    let dispatcher = IPaymentsDispatcher { contract_address };

    let order_1 = Order { sell_amount: 10, ..default_order() };
    let order_2 = Order { salt: 2, sell_amount: 20, ..default_order() };
    let order_3 = Order { salt: 3, sell_amount: 30, ..default_order() };
    let orders = array![order_1, order_2, order_3];
    let order_hashes = array![
        3250832918082879608022746380123673061315069847566627860201489924189339339467,
        3259641975931468454375849282716321416060344786234492516391729290818542841802,
        3472711217305392937857639177600091754979974757056915903236482173645832579133,
    ];

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
