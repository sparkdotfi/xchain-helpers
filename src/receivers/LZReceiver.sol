// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import { Address } from "lib/openzeppelin-contracts/contracts/utils/Address.sol";

struct Origin {
    uint32  srcEid;
    bytes32 sender;
    uint64  nonce;
}

/**
 * @title  LZReceiver
 * @notice Receive messages from LayerZero-style bridge.
 */
contract LZReceiver {

    using Address for address;

    address public immutable destinationEndpoint;
    address public immutable target;

    uint32  public immutable srcEid;

    bytes32 public immutable sourceAuthority;

    constructor(
        address _destinationEndpoint,
        uint32  _srcEid,
        bytes32 _sourceAuthority,
        address _target
    ) {
        destinationEndpoint = _destinationEndpoint;
        target              = _target;
        sourceAuthority     = _sourceAuthority;
        srcEid              = _srcEid;
    }

    function lzReceive(
        Origin calldata _origin,
        bytes32,  // _guid
        bytes calldata _message,
        address,  // _executor,
        bytes calldata  // _extraData
    ) external {
        require(msg.sender == destinationEndpoint,   "LZReceiver/invalid-sender");
        require(_origin.srcEid == srcEid,          "LZReceiver/invalid-srcEid");
        require(_origin.sender == sourceAuthority, "LZReceiver/invalid-sourceAuthority");

        target.functionCall(_message);
    }

    function allowInitializePath(Origin calldata origin) public view returns (bool) {
        return origin.srcEid == srcEid && origin.sender == sourceAuthority;
    }

}
