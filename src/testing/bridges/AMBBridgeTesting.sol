// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { Vm }        from "forge-std/Vm.sol";

import { Bridge }                from "../Bridge.sol";
import { Domain, DomainHelpers } from "../Domain.sol";
import { RecordedLogs }          from "../utils/RecordedLogs.sol";

interface IAMB {
    function validatorContract() external view returns (address);
    function executeSignatures(bytes memory, bytes memory) external;
    function executeAffirmation(bytes memory) external;
}

interface IValidatorContract {
    function validatorList() external view returns (address[] memory);
    function requiredSignatures() external view returns (uint256);
}

library AMBBridgeTesting {

    using DomainHelpers for *;
    using RecordedLogs  for *;

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 private constant USER_REQUEST_FOR_AFFIRMATION_TOPIC = keccak256("UserRequestForAffirmation(bytes32,bytes)");
    bytes32 private constant USER_REQUEST_FOR_SIGNATURE_TOPIC   = keccak256("UserRequestForSignature(bytes32,bytes)");
    
    function createGnosisBridge(Domain memory source, Domain memory destination) internal returns (Bridge memory bridge) {
        return init(Bridge({
            source:                         source,
            destination:                    destination,
            sourceCrossChainMessenger:      getGnosisMessengerFromChainAlias(source.chain.chainAlias),
            destinationCrossChainMessenger: getGnosisMessengerFromChainAlias(destination.chain.chainAlias),
            lastSourceLogIndex:             0,
            lastDestinationLogIndex:        0,
            extraData:                      ""
        }));
    }

    function getGnosisMessengerFromChainAlias(string memory chainAlias) internal pure returns (address) {
        bytes32 name = keccak256(bytes(chainAlias));
        if (name == keccak256("mainnet")) {
            return 0x4C36d2919e407f0Cc2Ee3c993ccF8ac26d9CE64e;
        } else if (name == keccak256("gnosis_chain")) {
            return 0x75Df5AF045d91108662D8080fD1FEFAd6aA0bb59;
        } else {
            revert("Unsupported chain");
        }
    }

    function init(Bridge memory bridge) internal returns (Bridge memory) {
        RecordedLogs.init();

         // Set minimum required signatures to zero for both domains
        bridge.destination.selectFork();
        vm.store(
            IAMB(bridge.destinationCrossChainMessenger).validatorContract(),
            0x8a247e09a5673bd4d93a4e76d8fb9553523aa0d77f51f3d576e7421f5295b9bc,
            0
        );
        bridge.source.selectFork();
        vm.store(
            IAMB(bridge.sourceCrossChainMessenger).validatorContract(),
            0x8a247e09a5673bd4d93a4e76d8fb9553523aa0d77f51f3d576e7421f5295b9bc,
            0
        );

        return bridge;
    }

    function relayMessagesToDestination(Bridge storage bridge, bool switchToDestinationFork) internal {
        bridge.destination.selectFork();

        Vm.Log[] memory logs = bridge.ingestAndFilterLogs(true, USER_REQUEST_FOR_AFFIRMATION_TOPIC, USER_REQUEST_FOR_SIGNATURE_TOPIC, bridge.sourceCrossChainMessenger);
        _relayAllMessages(logs, bridge.destinationCrossChainMessenger);

        if (!switchToDestinationFork) {
            bridge.source.selectFork();
        }
    }

    function relayMessagesToSource(Bridge storage bridge, bool switchToSourceFork) internal {
        bridge.source.selectFork();

        Vm.Log[] memory logs = bridge.ingestAndFilterLogs(false, USER_REQUEST_FOR_AFFIRMATION_TOPIC, USER_REQUEST_FOR_SIGNATURE_TOPIC, bridge.destinationCrossChainMessenger);
        _relayAllMessages(logs, bridge.sourceCrossChainMessenger);

        if (!switchToSourceFork) {
            bridge.destination.selectFork();
        }
    }

    function _relayAllMessages(Vm.Log[] memory logs, address amb) private {
        for (uint256 i = 0; i < logs.length; i++) {
            Vm.Log memory log = logs[i];
            bytes memory messageToRelay = abi.decode(log.data, (bytes));
            if (log.topics[0] == USER_REQUEST_FOR_AFFIRMATION_TOPIC) {
                vm.prank(IValidatorContract(IAMB(amb).validatorContract()).validatorList()[0]);
                IAMB(amb).executeAffirmation(messageToRelay);
            } else if (log.topics[0] == USER_REQUEST_FOR_SIGNATURE_TOPIC) {
                IAMB(amb).executeSignatures(messageToRelay, abi.encodePacked(uint256(0)));
            }
        }
    }

}
