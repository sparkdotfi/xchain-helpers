// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

struct MessagingParams {
    uint32  dstEid;
    bytes32 receiver;
    bytes   message;
    bytes   options;
    bool    payInLzToken;
}

struct MessagingReceipt {
    bytes32      guid;
    uint64       nonce;
    MessagingFee fee;
}

struct MessagingFee {
    uint256 nativeFee;
    uint256 lzTokenFee;
}

interface ILayerZeroEndpointV2 {
    function send(
        MessagingParams calldata _params,
        address                  _refundAddress
    ) external payable returns (MessagingReceipt memory);
}

library LZForwarder {

    function sendMessage(
        uint32               _dstEid,
        bytes32              _peer,
        ILayerZeroEndpointV2 endpoint,
        bytes         memory _message,
        bytes         memory _options
    ) internal {
        endpoint.send{ value: msg.value }(
            MessagingParams({
                dstEid:       _dstEid,
                receiver:     _peer,
                message:      _message,
                options:      _options,
                payInLzToken: false
            }),
            msg.sender
        );
    }

}
