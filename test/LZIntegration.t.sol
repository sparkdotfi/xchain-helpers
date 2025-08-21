// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./IntegrationBase.t.sol";

import { OptionsBuilder } from "layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

import { LZBridgeTesting }                   from "src/testing/bridges/LZBridgeTesting.sol";
import { LZForwarder, ILayerZeroEndpointV2 } from "src/forwarders/LZForwarder.sol";
import { LZReceiver, Origin }                from "src/receivers/LZReceiver.sol";

import { RecordedLogs } from "src/testing/utils/RecordedLogs.sol";

contract LZIntegrationTest is IntegrationBaseTest {

    using DomainHelpers   for *;
    using LZBridgeTesting for *;
    using OptionsBuilder  for bytes;

    uint32 sourceEndpointId = LZForwarder.ENDPOINT_ID_ETHEREUM;
    uint32 destinationEndpointId;

    address sourceEndpoint = LZForwarder.ENDPOINT_ETHEREUM;
    address destinationEndpoint;

    Domain destination2;
    Bridge bridge2;

    function test_invalidSender() public {
        destinationEndpointId = LZForwarder.ENDPOINT_ID_BASE;
        destinationEndpoint   = LZForwarder.ENDPOINT_BASE;
        initBaseContracts(getChain("base").createFork());

        destination.selectFork();

        vm.prank(randomAddress);
        vm.expectRevert("LZReceiver/invalid-sender");
        LZReceiver(destinationReceiver).lzReceive(
            Origin({
                srcEid: sourceEndpointId,
                sender: bytes32(uint256(uint160(sourceAuthority))),
                nonce:  1
            }),
            bytes32(0),
            abi.encodeCall(MessageOrdering.push, (1)),
            address(0),
            ""
        );
    }

    function test_invalidSourceEid() public {
        destinationEndpointId = LZForwarder.ENDPOINT_ID_BASE;
        destinationEndpoint   = LZForwarder.ENDPOINT_BASE;
        initBaseContracts(getChain("base").createFork());

        destination.selectFork();

        vm.prank(bridge.destinationCrossChainMessenger);
        vm.expectRevert("LZReceiver/invalid-srcEid");
        LZReceiver(destinationReceiver).lzReceive(
            Origin({
                srcEid: 0,
                sender: bytes32(uint256(uint160(sourceAuthority))),
                nonce:  1
            }),
            bytes32(0),
            abi.encodeCall(MessageOrdering.push, (1)),
            address(0),
            ""
        );
    }

    function test_invalidSourceAuthority() public {
        destinationEndpointId = LZForwarder.ENDPOINT_ID_BASE;
        destinationEndpoint   = LZForwarder.ENDPOINT_BASE;
        initBaseContracts(getChain("base").createFork());

        destination.selectFork();

        vm.prank(bridge.destinationCrossChainMessenger);
        vm.expectRevert("LZReceiver/invalid-sourceAuthority");
        LZReceiver(destinationReceiver).lzReceive(
            Origin({
                srcEid: sourceEndpointId,
                sender: bytes32(uint256(uint160(randomAddress))),
                nonce:  1
            }),
            bytes32(0),
            abi.encodeCall(MessageOrdering.push, (1)),
            address(0),
            ""
        );
    }

    function test_base() public {
        destinationEndpointId = LZForwarder.ENDPOINT_ID_BASE;
        destinationEndpoint   = LZForwarder.ENDPOINT_BASE;

        runCrossChainTests(getChain("base").createFork());
    }

    function test_binance() public {
        destinationEndpointId = LZForwarder.ENDPOINT_ID_BNB;
        destinationEndpoint   = LZForwarder.ENDPOINT_BNB;

        runCrossChainTests(getChain("bnb_smart_chain").createFork());
    }

    function initSourceReceiver() internal override returns (address) {
        return address(new LZReceiver(sourceEndpoint, destinationEndpointId, bytes32(uint256(uint160(destinationAuthority))), address(moSource)));
    }

    function initDestinationReceiver() internal override returns (address) {
        return address(new LZReceiver(destinationEndpoint, sourceEndpointId, bytes32(uint256(uint160(sourceAuthority))), address(moDestination)));
    }

    function initBridgeTesting() internal override returns (Bridge memory) {
        return LZBridgeTesting.createLZBridge(source, destination);
    }

    function queueSourceToDestination(bytes memory message) internal override {
        vm.deal(sourceAuthority, 1 ether);  // Gas to queue message

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200_000, 0);

        LZForwarder.sendMessage(
            destinationEndpointId,
            bytes32(uint256(uint160(destinationReceiver))),
            ILayerZeroEndpointV2(bridge.sourceCrossChainMessenger),
            message,
            options
        );
    }

    function queueDestinationToSource(bytes memory message) internal override {
        vm.deal(destinationAuthority, 1 ether);  // Gas to queue message

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200_000, 0);

        LZForwarder.sendMessage(
            sourceEndpointId,
            bytes32(uint256(uint160(sourceReceiver))),
            ILayerZeroEndpointV2(bridge.destinationCrossChainMessenger),
            message,
            options
        );
    }

    function relaySourceToDestination() internal override {
        bridge.relayMessagesToDestination(true, sourceAuthority, destinationReceiver);
    }

    function relayDestinationToSource() internal override {
        bridge.relayMessagesToSource(true, destinationAuthority, sourceReceiver);
    }

}
