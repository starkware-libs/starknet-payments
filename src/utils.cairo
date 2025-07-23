use openzeppelin::account::interface::{ISRC6Dispatcher, ISRC6DispatcherTrait};
use starknet::ContractAddress;
use crate::errors::{INVALID_STARK_SIGNATURE, UNALLOWED_ADDRESS};

// TODO(Mohammad): check if similar util is already implemented. if not move it to `starkware_utils`
// repo.
fn is_span_contains(element: ContractAddress, span: Span<ContractAddress>) -> bool {
    for addr in span {
        if *addr == element {
            return true;
        }
    }
    false
}

pub fn validate_allowed_addresses(
    owner: ContractAddress, allowed_addresses: Span<ContractAddress>,
) {
    // Means all addresses are allowed.
    if allowed_addresses.len() == 0 {
        return;
    }

    assert(is_span_contains(owner, allowed_addresses), UNALLOWED_ADDRESS);
}

pub fn assert_valid_signature(signer: ContractAddress, hash: felt252, signature: Span<felt252>) {
    let is_valid_signature_felt = ISRC6Dispatcher { contract_address: signer }
        .is_valid_signature(hash, signature.into());

    // Check either 'VALID' or true for backwards compatibility
    let is_valid_signature = is_valid_signature_felt == starknet::VALIDATED
        || is_valid_signature_felt == 1;

    assert(is_valid_signature, INVALID_STARK_SIGNATURE);
}

