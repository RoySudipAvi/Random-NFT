//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {
    RandomNft,
    MoreThanAllotedAddress,
    NotProperMIntingWindow,
    NotAuthorizedToMint,
    NotEnoughMintAmount,
    MintLimitExceeding,
    NotEnoughContractBalance
} from "src/RandomNft.sol";
import {RandomNftDeployment} from "script/RandomNft.s.sol";

contract RandomNftTest is Test {
    string private constant s_unrevealedURI = "ipfs://Qmbd1FLWeqaceTuX4a6vEY9EarsRgHijbS2NwVafLzc2Cj/";
    string private constant s_baseURI = "ipfs://QmaRtKneMK1KfbPwzjepwRH34Ls1LVZKgoQJnr16b9m2TW/";
    RandomNft private s_randomNft;
    RandomNftDeployment private s_deployment;
    address[] private s_whitelistAddresses;

    function setUp() external {
        s_deployment = new RandomNftDeployment();
        s_randomNft = s_deployment.run();
    }

    function setUpWhitelistAddresses() private {
        s_whitelistAddresses.push(0xBcd4042DE499D14e55001CcbB24a551F3b954096);
        s_whitelistAddresses.push(0x71bE63f3384f5fb98995898A86B02Fb2426c5788);
        s_whitelistAddresses.push(0x1CBd3b2770909D4e10f157cABC84C7264073C9Ec);
        s_whitelistAddresses.push(0xdF3e18d64BC6A983f673Ab319CCaE4f1a57C7097);
        s_whitelistAddresses.push(0xFABB0ac9d68B0B445fB7357272Ff202C5651694a);
    }

    function testUnrevealedUri() external view {
        assertEq(keccak256(abi.encodePacked(s_randomNft.getBaseUri())), keccak256(abi.encodePacked(s_unrevealedURI)));
    }

    function testGetBaseUri() external {
        vm.startPrank(s_deployment.s_mintAdmin());
        s_randomNft.setBaseURI(s_baseURI);
        s_randomNft.setMintStatus(RandomNft.MintingStatus.revealed);
        vm.stopPrank();
        assertEq(keccak256(abi.encodePacked(s_randomNft.getBaseUri())), keccak256(abi.encodePacked(s_baseURI)));
    }

    function testSetMintStatusRevertUnauthorized() external {
        vm.expectRevert();
        s_randomNft.setMintStatus(RandomNft.MintingStatus.revealed);
    }

    function testSetMintStatus() external {
        vm.prank(s_deployment.s_mintAdmin());
        s_randomNft.setMintStatus(RandomNft.MintingStatus.revealed);
        assert(s_randomNft.getCurrentStatus() == RandomNft.MintingStatus.revealed);
    }

    function testAddToWhitelistRevertUnauthorized() external {
        setUpWhitelistAddresses();
        vm.expectRevert();
        s_randomNft.addToWhitelist(s_whitelistAddresses);
    }

    function testAddToWhitelistRevertExceedsAllocationNumber() external {
        setUpWhitelistAddresses();
        s_whitelistAddresses.push(0xcd3B766CCDd6AE721141F452C550Ca635964ce71);
        vm.prank(s_deployment.s_mintAdmin());
        vm.expectRevert(MoreThanAllotedAddress.selector);
        s_randomNft.addToWhitelist(s_whitelistAddresses);
    }

    function testAddressGettingWhitelisted() external {
        setUpWhitelistAddresses();
        vm.prank(s_deployment.s_mintAdmin());
        s_randomNft.addToWhitelist(s_whitelistAddresses);
        assertTrue(s_randomNft.isAddressWhitelisted(0xFABB0ac9d68B0B445fB7357272Ff202C5651694a));
    }

    function testWhitelistMintRevertWhenPaused() external {
        vm.expectRevert();
        s_randomNft.whitelistMint();
    }

    function testWhitelistMintRevertWhenMintStatusNotWhitelist() external {
        vm.startPrank(s_deployment.s_mintAdmin());
        s_randomNft.unpause();
        s_randomNft.setMintStatus(RandomNft.MintingStatus.publicmint);
        vm.stopPrank();
        vm.expectRevert(
            abi.encodeWithSelector(
                NotProperMIntingWindow.selector,
                RandomNft.MintingStatus.whitelistmint,
                RandomNft.MintingStatus.publicmint
            )
        );
        s_randomNft.whitelistMint();
    }

    function testWhitelistMintRevertWhenUnauthorized() external {
        vm.prank(s_deployment.s_mintAdmin());
        s_randomNft.unpause();
        vm.expectRevert(
            abi.encodeWithSelector(
                NotAuthorizedToMint.selector, address(this), s_randomNft.isAddressWhitelisted(address(this))
            )
        );
        s_randomNft.whitelistMint();
    }

    function testWhitelistRevertWhenWrongMintAmount() external {
        setUpWhitelistAddresses();
        vm.startPrank(s_deployment.s_mintAdmin());
        s_randomNft.addToWhitelist(s_whitelistAddresses);
        s_randomNft.unpause();
        vm.stopPrank();
        vm.prank(s_whitelistAddresses[3]);
        vm.deal(s_whitelistAddresses[3], 1 ether);
        vm.expectRevert(abi.encodeWithSelector(NotEnoughMintAmount.selector, s_whitelistAddresses[3], 0.0005 ether));
        s_randomNft.whitelistMint{value: 0.0005 ether}();
    }

    function testAddressGettingRemovedFromWhitelistAfterMint() external {
        setUpWhitelistAddresses();
        vm.startPrank(s_deployment.s_mintAdmin());
        s_randomNft.addToWhitelist(s_whitelistAddresses);
        s_randomNft.unpause();
        vm.stopPrank();
        vm.prank(s_whitelistAddresses[3]);
        vm.deal(s_whitelistAddresses[3], 1 ether);
        s_randomNft.whitelistMint{value: 0.001 ether}();
        assertFalse(s_randomNft.isAddressWhitelisted(s_whitelistAddresses[3]));
    }

    function testAddressgettingMappedToTokenAfterWhitelistMint() external {
        setUpWhitelistAddresses();
        vm.startPrank(s_deployment.s_mintAdmin());
        s_randomNft.addToWhitelist(s_whitelistAddresses);
        s_randomNft.unpause();
        vm.stopPrank();
        vm.prank(s_whitelistAddresses[3]);
        vm.deal(s_whitelistAddresses[3], 1 ether);
        s_randomNft.whitelistMint{value: 0.001 ether}();
        assertTrue(s_randomNft.checkIfTokenMintedByAddress(s_whitelistAddresses[3], 1));
    }

    function testPublicMintRevertWhenMintStatusNotPublic() external {
        vm.startPrank(s_deployment.s_mintAdmin());
        s_randomNft.unpause();
        vm.stopPrank();
        vm.expectRevert(
            abi.encodeWithSelector(
                NotProperMIntingWindow.selector,
                RandomNft.MintingStatus.publicmint,
                RandomNft.MintingStatus.whitelistmint
            )
        );
        s_randomNft.publicMint();
    }

    function testPublicMintRevertWhenWrongMintAmount() external {
        vm.startPrank(s_deployment.s_mintAdmin());
        s_randomNft.setMintStatus(RandomNft.MintingStatus.publicmint);
        s_randomNft.unpause();
        vm.stopPrank();
        vm.prank(address(99));
        vm.deal(address(99), 1 ether);
        vm.expectRevert(abi.encodeWithSelector(NotEnoughMintAmount.selector, address(99), 0.0005 ether));
        s_randomNft.publicMint{value: 0.0005 ether}();
    }

    function testPublicMintRevertWhenLimitExceeds() external {
        vm.startPrank(s_deployment.s_mintAdmin());
        s_randomNft.setMintStatus(RandomNft.MintingStatus.publicmint);
        s_randomNft.unpause();
        vm.stopPrank();
        vm.prank(address(99));
        vm.deal(address(99), 1 ether);
        s_randomNft.publicMint{value: 0.001 ether}();
        vm.prank(address(99));
        vm.deal(address(99), 1 ether);
        s_randomNft.publicMint{value: 0.001 ether}();
        vm.prank(address(99));
        vm.deal(address(99), 1 ether);
        vm.expectRevert(MintLimitExceeding.selector);
        s_randomNft.publicMint{value: 0.001 ether}();
    }

    function testAddressgettingMappedToTokenAfterPublicMint() external {
        vm.startPrank(s_deployment.s_mintAdmin());
        s_randomNft.setMintStatus(RandomNft.MintingStatus.publicmint);
        s_randomNft.unpause();
        vm.stopPrank();
        vm.prank(address(99));
        vm.deal(address(99), 1 ether);
        s_randomNft.publicMint{value: 0.001 ether}();
        assertTrue(s_randomNft.checkIfTokenMintedByAddress(address(99), 1));
    }

    function testRevertMintsWithPausedWhenMintisOver() external {
        setUpWhitelistAddresses();
        vm.startPrank(s_deployment.s_mintAdmin());
        s_randomNft.addToWhitelist(s_whitelistAddresses);
        s_randomNft.unpause();
        vm.stopPrank();
        for (uint256 i = 0; i < s_whitelistAddresses.length; i++) {
            vm.prank(s_whitelistAddresses[i]);
            vm.deal(s_whitelistAddresses[i], 0.3 ether);
            s_randomNft.whitelistMint{value: 0.001 ether}();
        }
        vm.startPrank(s_deployment.s_mintAdmin());
        s_randomNft.setMintStatus(RandomNft.MintingStatus.publicmint);
        vm.stopPrank();
        for (uint160 i = 15; i < 28; i++) {
            vm.prank(address(i));
            vm.deal(address(i), 0.3 ether);
            s_randomNft.publicMint{value: 0.001 ether}();
        }

        vm.prank(address(75));
        vm.deal(address(75), 0.3 ether);
        vm.expectRevert();
        s_randomNft.publicMint{value: 0.001 ether}();
    }

    function testWithdrawRevertifUnauthorized() external {
        setUpWhitelistAddresses();
        vm.startPrank(s_deployment.s_mintAdmin());
        s_randomNft.addToWhitelist(s_whitelistAddresses);
        s_randomNft.unpause();
        vm.stopPrank();
        vm.prank(s_whitelistAddresses[3]);
        vm.deal(s_whitelistAddresses[3], 1 ether);
        s_randomNft.whitelistMint{value: 0.001 ether}();
        vm.expectRevert();
        s_randomNft.withdraw(0.0005 ether);
    }

    function testWithdrawRevertIfAmountGivenExceedsBalance() external {
        vm.prank(msg.sender);
        vm.expectRevert(
            abi.encodeWithSelector(NotEnoughContractBalance.selector, address(s_randomNft).balance, 0.001 ether)
        );
        s_randomNft.withdraw(0.001 ether);
    }

    function testWithdrawEmitsOnSuccess() external {
        setUpWhitelistAddresses();
        vm.startPrank(s_deployment.s_mintAdmin());
        s_randomNft.addToWhitelist(s_whitelistAddresses);
        s_randomNft.unpause();
        vm.stopPrank();
        vm.prank(s_whitelistAddresses[3]);
        vm.deal(s_whitelistAddresses[3], 1 ether);
        s_randomNft.whitelistMint{value: 0.001 ether}();
        vm.expectEmit(true, true, false, false, address(s_randomNft));
        emit RandomNft.FundWithdrawn({_amount: 0.0005 ether, _withdrawnBy: msg.sender});
        vm.prank(msg.sender);
        s_randomNft.withdraw(0.0005 ether);
    }
}
