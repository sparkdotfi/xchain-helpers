// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import { CCTPForwarder }         from "src/forwarders/CCTPForwarder.sol";
import { CCTPBridgeTesting }     from "src/testing/bridges/CCTPBridgeTesting.sol";
import { Bridge }                from "src/testing/Bridge.sol";
import { Domain, DomainHelpers } from "src/testing/Domain.sol";
import { RecordedLogs }          from "src/testing/utils/RecordedLogs.sol";

contract DummyReceiver {

    function handleReceiveMessage(
        uint32,
        bytes32,
        bytes calldata
    ) external pure returns (bool) {
        return true;
    }
    
}

contract LogGenerator {

    event DummyEvent();

    function makeLogs(uint256 num) external {
        for (uint256 i = 0; i < num; i++) emit DummyEvent();
    }

}

contract RecordedLogsTest is Test {

    using DomainHelpers for *;
    using CCTPBridgeTesting for *;

    Domain source;
    Domain destination;

    Bridge bridge;

    function test_memory_oog() public {
        source      = getChain("mainnet").createFork();
        destination = getChain("base").createFork();

        bridge = CCTPBridgeTesting.createCircleBridge(source, destination);

        destination.selectFork();

        DummyReceiver r1 = new DummyReceiver();

        source.selectFork();

        // Generate a bunch of logs
        LogGenerator gen = new LogGenerator();
        gen.makeLogs(1000);

        // Comment this out to see MemoryOOG error
        RecordedLogs.clearLogs();

        CCTPForwarder.sendMessage(CCTPForwarder.MESSAGE_TRANSMITTER_CIRCLE_ETHEREUM, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE, address(r1), "");

        bridge.relayMessagesToDestination(true);
    }

}
