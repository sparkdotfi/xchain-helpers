// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { Vm } from "forge-std/Vm.sol";

import { Bridge } from "../Bridge.sol";

contract RecordedLogsStorage {

    uint256 public forkId;

    function setForkId(uint256 _forkId) external {
        forkId = _forkId;
    }

    function storeBytes(bytes memory data) external {
        uint256 len = data.length;
        uint256 chunks = (len + 31) / 32;

        assembly {
            tstore(0, len)
        }

        for (uint256 i = 0; i < chunks; i++) {
            bytes32 chunk;
            assembly {
                chunk := mload(add(data, add(32, mul(i, 32))))
                tstore(add(i, 1), chunk)
            }
        }
    }

    function getBytes() external view returns (bytes memory data) {
        uint256 len;
        
        assembly {
            len := tload(0)
        }
        
        data = new bytes(len);
        uint256 chunks = (len + 31) / 32;
        
        for (uint256 i = 0; i < chunks; i++) {
            bytes32 chunk;
            assembly {
                chunk := tload(add(i, 1))
                mstore(add(data, add(32, mul(i, 32))), chunk) // Store chunk into memory
            }
        }
    }

    function clearLogs() external {
        assembly {
            tstore(0, 0)
        }
    }

}

library RecordedLogs {

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    address private constant STORAGE = address(uint160(uint256(keccak256("__RecordedLogsStorage__"))));

    function init() internal {
        bytes memory bytecode = vm.getCode("RecordedLogs.sol:RecordedLogsStorage");
        address deployed;
        assembly {
            deployed := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        vm.etch(STORAGE, deployed.code);
        vm.makePersistent(STORAGE);
        // The fork doesn't really matter we just use this to store the logs on the same place
        RecordedLogsStorage(STORAGE).setForkId(vm.createFork(vm.envString("MAINNET_RPC_URL")));

        vm.recordLogs();
    }

    function getLogs() internal returns (Vm.Log[] memory) {
        bool isActiveFork = false;
        uint256 prevForkId;
        try vm.activeFork() returns (uint256 forkId) {
            prevForkId = forkId;
            vm.selectFork(RecordedLogsStorage(STORAGE).forkId());
            isActiveFork = true;
        } catch {}

        // Fetch new logs
        Vm.Log[] memory newLogs = vm.getRecordedLogs();

        // Decode the old logs from storage
        Vm.Log[] memory oldLogs;
        bytes memory oldEncodedLogsBytes = RecordedLogsStorage(STORAGE).getBytes();
        if (oldEncodedLogsBytes.length > 0) {
            bytes[] memory oldEncodedLogs = abi.decode(oldEncodedLogsBytes, (bytes[]));
            oldLogs = new Vm.Log[](oldEncodedLogs.length);
            for (uint256 i = 0; i < oldEncodedLogs.length; i++) {
                (oldLogs[i].topics, oldLogs[i].data, oldLogs[i].emitter) = abi.decode(oldEncodedLogs[i], (bytes32[], bytes, address));
            }
        }

        // Merge them together
        Vm.Log[] memory logs = new Vm.Log[](oldLogs.length + newLogs.length);
        for (uint256 i = 0; i < oldLogs.length; i++) {
            logs[i] = oldLogs[i];
        }
        for (uint256 i = 0; i < newLogs.length; i++) {
            logs[oldLogs.length + i] = newLogs[i];
        }

        // Write the combined logs back to storage
        bytes[] memory encodedLogs = new bytes[](logs.length);
        for (uint256 i = 0; i < logs.length; i++) {
            encodedLogs[i] = abi.encode(logs[i].topics, logs[i].data, logs[i].emitter);
        }
        RecordedLogsStorage(STORAGE).storeBytes(abi.encode(encodedLogs));
        
        if (isActiveFork) vm.selectFork(prevForkId);

        return logs;
    }

    function clearLogs() internal {
        bool isActiveFork = false;
        uint256 prevForkId;
        try vm.activeFork() returns (uint256 forkId) {
            prevForkId = forkId;
            vm.selectFork(RecordedLogsStorage(STORAGE).forkId());
            isActiveFork = true;
        } catch {}

        vm.getRecordedLogs();
        RecordedLogsStorage(STORAGE).clearLogs();

        if (isActiveFork) vm.selectFork(prevForkId);
    }

    function ingestAndFilterLogs(Bridge storage bridge, bool sourceToDestination, bytes32 topic0, bytes32 topic1, address emitter) internal returns (Vm.Log[] memory filteredLogs) {
        Vm.Log[] memory logs = RecordedLogs.getLogs();
        uint256 lastIndex = sourceToDestination ? bridge.lastSourceLogIndex : bridge.lastDestinationLogIndex;
        uint256 pushedIndex = 0;

        filteredLogs = new Vm.Log[](logs.length - lastIndex);

        for (; lastIndex < logs.length; lastIndex++) {
            Vm.Log memory log = logs[lastIndex];
            if ((log.topics[0] == topic0 || log.topics[0] == topic1) && log.emitter == emitter) {
                filteredLogs[pushedIndex++] = log;
            }
        }

        if (sourceToDestination) bridge.lastSourceLogIndex = lastIndex;
        else bridge.lastDestinationLogIndex = lastIndex;
        // Reduce the array length
        assembly { mstore(filteredLogs, pushedIndex) }
    }

    function ingestAndFilterLogs(Bridge storage bridge, bool sourceToDestination, bytes32 topic, address emitter) internal returns (Vm.Log[] memory filteredLogs) {
        return ingestAndFilterLogs(bridge, sourceToDestination, topic, bytes32(0), emitter);
    }

}
