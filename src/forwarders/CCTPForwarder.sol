// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

interface IMessageTransmitter {
    function sendMessage(
        uint32 destinationDomain,
        bytes32 recipient,
        bytes calldata messageBody
    ) external;
}

library CCTPForwarder {

    address constant internal MESSAGE_TRANSMITTER_CIRCLE_ETHEREUM     = 0x0a992d191DEeC32aFe36203Ad87D7d289a738F81;
    address constant internal MESSAGE_TRANSMITTER_CIRCLE_AVALANCHE    = 0x8186359aF5F57FbB40c6b14A588d2A59C0C29880;
    address constant internal MESSAGE_TRANSMITTER_CIRCLE_OPTIMISM     = 0x4D41f22c5a0e5c74090899E5a8Fb597a8842b3e8;
    address constant internal MESSAGE_TRANSMITTER_CIRCLE_ARBITRUM_ONE = 0xC30362313FBBA5cf9163F0bb16a0e01f01A896ca;
    address constant internal MESSAGE_TRANSMITTER_CIRCLE_BASE         = 0xAD09780d193884d503182aD4588450C416D6F9D4;
    address constant internal MESSAGE_TRANSMITTER_CIRCLE_POLYGON_POS  = 0xF3be9355363857F3e001be68856A2f96b4C39Ba9;
    address constant internal MESSAGE_TRANSMITTER_CIRCLE_UNICHAIN     = 0x353bE9E2E38AB1D19104534e4edC21c643Df86f4;

    uint32 constant internal DOMAIN_ID_CIRCLE_ETHEREUM     = 0;
    uint32 constant internal DOMAIN_ID_CIRCLE_AVALANCHE    = 1;
    uint32 constant internal DOMAIN_ID_CIRCLE_OPTIMISM     = 2;
    uint32 constant internal DOMAIN_ID_CIRCLE_ARBITRUM_ONE = 3;
    uint32 constant internal DOMAIN_ID_CIRCLE_NOBLE        = 4;
    uint32 constant internal DOMAIN_ID_CIRCLE_SOLANA       = 5;
    uint32 constant internal DOMAIN_ID_CIRCLE_BASE         = 6;
    uint32 constant internal DOMAIN_ID_CIRCLE_POLYGON_POS  = 7;
    uint32 constant internal DOMAIN_ID_CIRCLE_UNICHAIN     = 10;

    function sendMessage(
        address messageTransmitter,
        uint32 destinationDomainId,
        bytes32 recipient,
        bytes memory messageBody
    ) internal {
        IMessageTransmitter(messageTransmitter).sendMessage(
            destinationDomainId,
            recipient,
            messageBody
        );
    }

    function sendMessage(
        address messageTransmitter,
        uint32 destinationDomainId,
        address recipient,
        bytes memory messageBody
    ) internal {
        sendMessage(
            messageTransmitter,
            destinationDomainId,
            bytes32(uint256(uint160(recipient))),
            messageBody
        );
    }
    
}
