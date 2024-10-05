//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {RandomNft} from "src/RandomNft.sol";

contract RandomNftDeployment is Script {
    RandomNft private s_randomNft;
    address public s_mintAdmin;

    function run() external returns (RandomNft) {
        if (block.chainid == 11155111) {
            s_mintAdmin = 0xCc51a734Fd91A26058F55C9BC083450E0c7D5Fcf;
        } else {
            s_mintAdmin = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
        }
        vm.startBroadcast();
        s_randomNft =
            new RandomNft("Random Nft", "RNDT", s_mintAdmin, "ipfs://Qmbd1FLWeqaceTuX4a6vEY9EarsRgHijbS2NwVafLzc2Cj/");
        vm.stopBroadcast();
        return s_randomNft;
    }
}
