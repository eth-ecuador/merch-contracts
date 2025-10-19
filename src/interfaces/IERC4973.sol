// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IERC4973
 * @dev Interface for ERC-4973 Soul Bound Tokens
 * @notice Account-bound tokens (non-transferable)
 */
interface IERC4973 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    /**
     * @dev Returns the owner of the `tokenId` token.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Returns the number of tokens owned by `owner`.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the token URI of the `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}