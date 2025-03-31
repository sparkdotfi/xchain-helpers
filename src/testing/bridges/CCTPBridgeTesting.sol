// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { Vm }        from "forge-std/Vm.sol";

import { Bridge }                from "../Bridge.sol";
import { Domain, DomainHelpers } from "../Domain.sol";
import { RecordedLogs }          from "../utils/RecordedLogs.sol";
import { CCTPForwarder }         from "../../forwarders/CCTPForwarder.sol";

interface IMessenger {
    function localDomain() external view returns (uint32);
    function receiveMessage(bytes calldata message, bytes calldata attestation) external returns (bool success);
}

library CCTPBridgeTesting {

    bytes32 private constant SENT_MESSAGE_TOPIC = keccak256("MessageSent(bytes)");

    using DomainHelpers for *;
    using RecordedLogs  for *;

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function createCircleBridge(Domain memory source, Domain memory destination) internal returns (Bridge memory bridge) {
        return init(Bridge({
            source:                         source,
            destination:                    destination,
            sourceCrossChainMessenger:      getCircleMessengerFromChainAlias(source.chain.chainAlias),
            destinationCrossChainMessenger: getCircleMessengerFromChainAlias(destination.chain.chainAlias),
            lastSourceLogIndex:             0,
            lastDestinationLogIndex:        0,
            extraData:                      ""
        }));
    }

    function getCircleMessengerFromChainAlias(string memory chainAlias) internal pure returns (address) {
        bytes32 name = keccak256(bytes(chainAlias));
        if (name == keccak256("mainnet")) {
            return CCTPForwarder.MESSAGE_TRANSMITTER_CIRCLE_ETHEREUM;
        } else if (name == keccak256("avalanche")) {
            return CCTPForwarder.MESSAGE_TRANSMITTER_CIRCLE_AVALANCHE;
        } else if (name == keccak256("optimism")) {
            return CCTPForwarder.MESSAGE_TRANSMITTER_CIRCLE_OPTIMISM;
        } else if (name == keccak256("arbitrum_one")) {
            return CCTPForwarder.MESSAGE_TRANSMITTER_CIRCLE_ARBITRUM_ONE;
        } else if (name == keccak256("base")) {
            return CCTPForwarder.MESSAGE_TRANSMITTER_CIRCLE_BASE;
        } else if (name == keccak256("polygon")) {
            return CCTPForwarder.MESSAGE_TRANSMITTER_CIRCLE_POLYGON_POS;
        } else {
            revert("Unsupported chain");
        }
    }

    function init(Bridge memory bridge) internal returns (Bridge memory) {
         // Set minimum required signatures to zero for both domains
        bridge.destination.selectFork();
        vm.store(
            bridge.destinationCrossChainMessenger,
            bytes32(uint256(4)),
            0
        );
        bridge.source.selectFork();
        vm.store(
            bridge.sourceCrossChainMessenger,
            bytes32(uint256(4)),
            0
        );

        RecordedLogs.init();

        return bridge;
    }

    function relayMessagesToDestination(Bridge storage bridge, bool switchToDestinationFork) internal {
        bridge.source.selectFork();
        uint32 sourceDomain = IMessenger(bridge.sourceCrossChainMessenger).localDomain();

        bridge.destination.selectFork();
        uint32 destinationDomain = IMessenger(bridge.destinationCrossChainMessenger).localDomain();

        bridge.destination.selectFork();

        Vm.Log[] memory logs = bridge.ingestAndFilterLogs(true, SENT_MESSAGE_TOPIC, bridge.sourceCrossChainMessenger);
        for (uint256 i = 0; i < logs.length; i++) {
            bytes memory message = abi.decode(logs[i].data, (bytes));
            uint32 messageDestinationDomain = getDestinationDomain(message);
            uint32 messageSourceDomain      = getSourceDomain(message);

            if (
                messageSourceDomain == sourceDomain &&
                messageDestinationDomain == destinationDomain
            ) {
                IMessenger(bridge.destinationCrossChainMessenger).receiveMessage(message, "");
            }
        }

        if (!switchToDestinationFork) {
            bridge.source.selectFork();
        }
    }

    function relayMessagesToSource(Bridge storage bridge, bool switchToSourceFork) internal {
        bridge.destination.selectFork();
        uint32 destinationDomain = IMessenger(bridge.destinationCrossChainMessenger).localDomain();

        bridge.source.selectFork();
        uint32 sourceDomain = IMessenger(bridge.sourceCrossChainMessenger).localDomain();

        Vm.Log[] memory logs = bridge.ingestAndFilterLogs(false, SENT_MESSAGE_TOPIC, bridge.destinationCrossChainMessenger);
        for (uint256 i = 0; i < logs.length; i++) {
            bytes memory message = abi.decode(logs[i].data, (bytes));
            uint32 messageDestinationDomain = getDestinationDomain(message);
            uint32 messageSourceDomain      = getSourceDomain(message);

            // NOTE: When relaying messages to the source domain, `destinationDomain` is the domain of the source chain
            //       and `sourceDomain` is the domain of the destination chain.
            if (
                messageSourceDomain == destinationDomain &&
                messageDestinationDomain == sourceDomain
            ) {
                IMessenger(bridge.sourceCrossChainMessenger).receiveMessage(message, "");
            }
        }

        if (!switchToSourceFork) {
            bridge.destination.selectFork();
        }
    }

    /**
     * @notice Extracts the destinationDomain (a uint32) from a message.
     * @param message The encoded message as a bytes array.
     * @return destinationDomain The extracted destinationDomain.
     *
     * Message format:
     * Field                 Bytes      Type       Index
     * version               4          uint32     0
     * sourceDomain          4          uint32     4
     * destinationDomain     4          uint32     8
     * nonce                 8          uint64     12
     * sender                32         bytes32    20
     * recipient             32         bytes32    52
     * messageBody           dynamic    bytes      84
     */
    function getDestinationDomain(bytes memory message) public pure returns (uint32 destinationDomain) {
        require(message.length >= 12, "Message too short");

        assembly {
            // Add 32 to skip the length word, then add 8 to reach the destinationDomain.
            // mload loads 32 bytes starting from that position.
            // The actual uint32 is in the top 4 bytes, so shift right by 224 bits.
            destinationDomain := shr(224, mload(add(message, 40)))
        }
    }

    // Uses same data structure as above for `message`
    function getSourceDomain(bytes memory message) public pure returns (uint32 sourceDomain) {
        require(message.length >= 8, "Message too short");

        assembly {
            // Add 32 to skip the length prefix, then add 4 bytes to reach sourceDomain
            // mload loads 32 bytes starting at that location
            // Since sourceDomain is a uint32 located at bytes 4–7, it's in the top 4 bytes of the word
            sourceDomain := shr(224, mload(add(message, 36)))
        }
    }

}
