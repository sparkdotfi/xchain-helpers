// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import { TargetContractMock } from "test/mocks/TargetContractMock.sol";

import { LZForwarder }        from "src/forwarders/LZForwarder.sol";
import { LZReceiver, Origin } from "src/receivers/LZReceiver.sol";

contract LZReceiverTest is Test {

    TargetContractMock target;

    LZReceiver receiver;

    address destinationEndpoint = LZForwarder.ENDPOINT_BNB;
    address randomAddress       = makeAddr("randomAddress");
    address sourceAuthority     = makeAddr("sourceAuthority");
    
    uint32 srcEid = LZForwarder.ENDPOINT_ID_ETHEREUM;

    function setUp() public {
        target = new TargetContractMock();

        receiver = new LZReceiver(
            destinationEndpoint,
            srcEid,
            bytes32(uint256(uint160(sourceAuthority))),
            address(target)
        );
    }

    function test_constructor() public {
        receiver = new LZReceiver(
            destinationEndpoint,
            srcEid,
            bytes32(uint256(uint160(sourceAuthority))),
            address(target)
        );

        assertEq(receiver.destinationEndpoint(), destinationEndpoint);
        assertEq(receiver.srcEid(),              srcEid);
        assertEq(receiver.sourceAuthority(),     bytes32(uint256(uint160(sourceAuthority))));
        assertEq(receiver.target(),              address(target));
    }

    function test_lzReceive_invalidSender() public {
        vm.prank(randomAddress);
        vm.expectRevert("LZReceiver/invalid-sender");
        receiver.lzReceive(
            Origin({
                srcEid: srcEid,
                sender: bytes32(uint256(uint160(sourceAuthority))),
                nonce:  1
            }),
            bytes32(0),
            abi.encodeCall(TargetContractMock.increment, ()),
            address(0),
            ""
        );
    }

    function test_lzReceive_invalidSrcEid() public {
        vm.prank(destinationEndpoint);
        vm.expectRevert("LZReceiver/invalid-srcEid");
        receiver.lzReceive(
            Origin({
                srcEid: srcEid + 1,
                sender: bytes32(uint256(uint160(sourceAuthority))),
                nonce:  1
            }),
            bytes32(0),
            abi.encodeCall(TargetContractMock.increment, ()),
            address(0),
            ""
        );
    }

    function test_lzReceive_invalidSourceAuthority() public {
        vm.prank(destinationEndpoint);
        vm.expectRevert("LZReceiver/invalid-sourceAuthority");
        receiver.lzReceive(
            Origin({
                srcEid: srcEid,
                sender: bytes32(uint256(uint160(randomAddress))),
                nonce:  1
            }),
            bytes32(0),
            abi.encodeCall(TargetContractMock.increment, ()),
            address(0),
            ""
        );
    }

    function test_lzReceive_success() public {
        assertEq(target.count(), 0);
        vm.prank(destinationEndpoint);
        receiver.lzReceive(
            Origin({
                srcEid: srcEid,
                sender: bytes32(uint256(uint160(sourceAuthority))),
                nonce:  1
            }),
            bytes32(0),
            abi.encodeCall(TargetContractMock.increment, ()),
            address(0),
            ""
        );
        assertEq(target.count(), 1);
    }

    function test_allowInitializePath() public view {
        // Should return true when origin.srcEid == srcEid and origin.sender == sourceAuthority
        assertTrue(receiver.allowInitializePath(Origin({
            srcEid: srcEid,
            sender: bytes32(uint256(uint160(sourceAuthority))),
            nonce:  1
        })));

        // Should return false when origin.srcEid != srcEid
        assertFalse(receiver.allowInitializePath(Origin({
            srcEid: srcEid + 1,
            sender: bytes32(uint256(uint160(sourceAuthority))),
            nonce:  1
        })));

        // Should return false when origin.sender != sourceAuthority
        assertFalse(receiver.allowInitializePath(Origin({
            srcEid: srcEid,
            sender: bytes32(uint256(uint160(randomAddress))),
            nonce:  1
        })));

        // Should return false when origin.srcEid != srcEid and origin.sender != sourceAuthority
        assertFalse(receiver.allowInitializePath(Origin({
            srcEid: srcEid + 1,
            sender: bytes32(uint256(uint160(randomAddress))),
            nonce:  1
        })));
    }
    
}
