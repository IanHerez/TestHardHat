// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";

contract StudyGuideNFT is ERC1155, Ownable, ReentrancyGuard, Pausable {
    using Strings for uint256;

    // Estructura para almacenar información de la guía
    struct StudyGuide {
        uint256 id;
        string title;
        string author;
        string description;
        string subject;
        uint256 price;
        address creator;
        bool isAvailable;
        uint256 totalSupply;
        uint256 minted;
        uint256 royaltyPercentage;
    }

    // Mapeos y variables
    mapping(uint256 => StudyGuide) public studyGuides;
    mapping(uint256 => string) private _tokenURIs;
    mapping(address => uint256[]) private _creatorGuides;
    mapping(uint256 => address[]) private _guideOwners;

    uint256 public guideCounter;
    uint256 public constant MAX_ROYALTY_PERCENTAGE = 1000; // 10%
    uint256 public constant BASIS_POINTS = 10000; // 100%

    // Eventos
    event GuideCreated(
        uint256 indexed id,
        address indexed creator,
        string title,
        uint256 price,
        uint256 totalSupply
    );
    event GuidePurchased(
        uint256 indexed id,
        address indexed buyer,
        uint256 amount,
        uint256 price
    );
    event GuideUpdated(uint256 indexed id, uint256 newPrice, bool isAvailable);
    event RoyaltyPaid(
        uint256 indexed id,
        address indexed creator,
        uint256 amount
    );
    event GuideBurned(
        uint256 indexed id,
        address indexed owner,
        uint256 amount
    );

    constructor() ERC1155("") Ownable(msg.sender) {}

    // Modificadores
    modifier guideExists(uint256 guideId) {
        require(
            guideId <= guideCounter && guideId > 0,
            unicode"La guía no existe"
        );
        _;
    }

    modifier onlyCreator(uint256 guideId) {
        require(
            studyGuides[guideId].creator == msg.sender,
            unicode"No le pertenece"
        );
        _;
    }

    // Funciones principales
    function createGuide(
        string memory title,
        string memory author,
        string memory description,
        string memory subject,
        uint256 price,
        uint256 totalSupply,
        uint256 royaltyPercentage,
        string memory uri_
    ) external whenNotPaused returns (uint256) {
        require(price > 0, unicode"El precio debe ser mayor que 0");
        require(
            totalSupply > 0,
            unicode"El suministro total debe ser mayor que 0"
        );
        require(
            royaltyPercentage <= MAX_ROYALTY_PERCENTAGE,
            unicode"El porcentaje de regalías es demasiado alto"
        );

        guideCounter++;
        uint256 newGuideId = guideCounter;

        studyGuides[newGuideId] = StudyGuide({
            id: newGuideId,
            title: title,
            author: author,
            description: description,
            subject: subject,
            price: price,
            creator: msg.sender,
            isAvailable: true,
            totalSupply: totalSupply,
            minted: 0,
            royaltyPercentage: royaltyPercentage
        });

        _tokenURIs[newGuideId] = uri_;
        _creatorGuides[msg.sender].push(newGuideId);

        emit GuideCreated(newGuideId, msg.sender, title, price, totalSupply);
        return newGuideId;
    }

    function purchaseGuide(
        uint256 guideId
    ) external payable whenNotPaused nonReentrant guideExists(guideId) {
        StudyGuide storage guide = studyGuides[guideId];
        require(guide.isAvailable, unicode"Guía no disponible");
        require(msg.value >= guide.price, unicode"Pago insuficiente");
        require(
            guide.minted < guide.totalSupply,
            unicode"Todas las copias minteadas"
        );

        // Calcular regalías
        uint256 royaltyAmount = (msg.value * guide.royaltyPercentage) /
            BASIS_POINTS;
        uint256 creatorAmount = royaltyAmount;
        uint256 platformAmount = msg.value - royaltyAmount;

        // Mintear NFT
        _mint(msg.sender, guideId, 1, "");
        guide.minted++;
        _guideOwners[guideId].push(msg.sender);

        // Transferir pagos
        if (royaltyAmount > 0) {
            payable(guide.creator).transfer(creatorAmount);
            emit RoyaltyPaid(guideId, guide.creator, creatorAmount);
        }
        payable(owner()).transfer(platformAmount);

        emit GuidePurchased(guideId, msg.sender, 1, msg.value);
    }

    // Funciones de administración
    function updateGuide(
        uint256 guideId,
        uint256 newPrice,
        bool isAvailable
    ) external onlyOwner guideExists(guideId) {
        StudyGuide storage guide = studyGuides[guideId];
        guide.price = newPrice;
        guide.isAvailable = isAvailable;
        emit GuideUpdated(guideId, newPrice, isAvailable);
    }

    function updateURI(
        uint256 guideId,
        string memory newURI
    ) external onlyOwner guideExists(guideId) {
        _tokenURIs[guideId] = newURI;
    }

    function setPaused(bool _paused) external onlyOwner {
        if (_paused) {
            _pause();
        } else {
            _unpause();
        }
    }

    // Funciones de consulta
    function uri(uint256 guideId) public view override returns (string memory) {
        return _tokenURIs[guideId];
    }

    function isGuideAvailable(uint256 guideId) external view returns (bool) {
        return
            studyGuides[guideId].isAvailable &&
            studyGuides[guideId].minted < studyGuides[guideId].totalSupply;
    }

    function getGuideInfo(
        uint256 guideId
    )
        external
        view
        returns (
            string memory title,
            string memory author,
            string memory description,
            string memory subject,
            uint256 price,
            address creator,
            bool isAvailable,
            uint256 totalSupply,
            uint256 minted,
            uint256 royaltyPercentage
        )
    {
        StudyGuide storage guide = studyGuides[guideId];
        return (
            guide.title,
            guide.author,
            guide.description,
            guide.subject,
            guide.price,
            guide.creator,
            guide.isAvailable,
            guide.totalSupply,
            guide.minted,
            guide.royaltyPercentage
        );
    }

    function getCreatorGuides(
        address creator
    ) external view returns (uint256[] memory) {
        return _creatorGuides[creator];
    }

    function getGuideOwners(
        uint256 guideId
    ) external view returns (address[] memory) {
        return _guideOwners[guideId];
    }

    // Funciones de quema
    function burn(uint256 guideId, uint256 amount) external {
        require(
            balanceOf(msg.sender, guideId) >= amount,
            unicode"Saldo insuficiente"
        );
        _burn(msg.sender, guideId, amount);
        emit GuideBurned(guideId, msg.sender, amount);
    }

    // Función de retiro de fondos
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, unicode"No hay fondos para retirar");
        payable(owner()).transfer(balance);
    }

    // Función de emergencia
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, unicode"No hay fondos para retirar");
        payable(owner()).transfer(balance);
    }

    // Función para recibir ETH
    receive() external payable {}
}
