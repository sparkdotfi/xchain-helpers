// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import { CCTPForwarder }         from "src/forwarders/CCTPForwarder.sol";
import { CCTPBridgeTesting }     from "src/testing/bridges/CCTPBridgeTesting.sol";
import { Bridge }                from "src/testing/Bridge.sol";
import { Domain, DomainHelpers } from "src/testing/Domain.sol";
import { RecordedLogs }          from "src/testing/utils/RecordedLogs.sol";

contract DummyReceiver {

    bytes public data;

    function handleReceiveMessage(
        uint32,
        bytes32,
        bytes calldata _data
    ) external returns (bool) {
        data = _data;

        return true;
    }
    
}

contract LogGenerator {

    event DummyEvent(string label, uint256 num);

    string label;

    constructor(string memory _label) {
        label = _label;
    }

    function makeLogs(uint256 num) external {
        for (uint256 i = 0; i < num; i++) emit DummyEvent(label, i);
    }

}

contract RecordedLogsTest is Test {

    using DomainHelpers for *;
    using CCTPBridgeTesting for *;

    Domain source;
    Domain destination;

    Bridge bridge;

    function setUp() public {
        RecordedLogs.init();
    }

    function test_logs_fetch() public {
        // We use unique label between tests to make sure there is no interference between tests
        string memory label = "test1";
        LogGenerator gen = new LogGenerator(label);
        gen.makeLogs(2);

        Vm.Log[] memory logs = RecordedLogs.getLogs();

        assertEq(logs.length, 2);
        assertEq(logs[0].data, abi.encode(label, 0));
        assertEq(logs[1].data, abi.encode(label, 1));
    }

    function test_logs_persists() public {
        string memory label = "test2";
        LogGenerator gen = new LogGenerator(label);
        gen.makeLogs(1);

        Vm.Log[] memory logs = RecordedLogs.getLogs();

        assertEq(logs.length, 1);
        assertEq(logs[0].data, abi.encode(label, 0));

        gen.makeLogs(2);

        Vm.Log[] memory logs2 = RecordedLogs.getLogs();

        assertEq(logs2.length, 3);
        assertEq(logs2[0].data, abi.encode(label, 0));
        assertEq(logs2[1].data, abi.encode(label, 0));
        assertEq(logs2[2].data, abi.encode(label, 1));
    }

    function test_performance() public {
        // This will generate 1k logs
        for (uint256 i = 0; i < 10; i++) {
            LogGenerator gen = new LogGenerator("performance");
            gen.makeLogs(100);
            Vm.Log[] memory logs = RecordedLogs.getLogs();
            assertEq(logs.length, 100 * (i + 1));
        }
    }

    function test_multichain() public {
        source      = getChain("mainnet").createFork();
        destination = getChain("base").createFork();

        bridge = CCTPBridgeTesting.createCircleBridge(source, destination);

        destination.selectFork();

        DummyReceiver r1 = new DummyReceiver();

        source.selectFork();

        // Generate a bunch of logs
        LogGenerator gen = new LogGenerator("multichain");
        gen.makeLogs(10000);

        CCTPForwarder.sendMessage(CCTPForwarder.MESSAGE_TRANSMITTER_CIRCLE_ETHEREUM, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE, address(r1), "123");

        destination.selectFork();

        assertEq(r1.data(), bytes(""));

        bridge.relayMessagesToDestination(true);

        assertEq(r1.data(), bytes("123"));
    }

}
