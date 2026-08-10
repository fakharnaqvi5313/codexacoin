// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice A wrapped, reserve-backed representation of CAC on BNB Smart
/// Chain -- an IOU, not a bridge, same pattern as the Stellar CAC asset
/// and CodexaCoinBase.sol on Base (see stellar-issuer/README.md for why
/// no trustless bridge is possible for an external UTXO chain). This is
/// a third, separate custodial liability from the Stellar and Base
/// ones: its own reserve wallet, its own supply, its own disclosure.
/// The entire supply mints once, here, at construction. There is no
/// owner, no mint function, and no admin role of any kind.
contract CodexaCoinBnb is ERC20 {
    constructor(uint256 initialSupply, address reserveBackedRecipient)
        ERC20("CodexaCoin", "CAC")
    {
        _mint(reserveBackedRecipient, initialSupply);
    }
}
