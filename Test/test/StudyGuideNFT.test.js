const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("StudyGuideNFT", function () {
  let StudyGuideNFT;
  let studyGuideNFT;
  let owner;
  let creator;
  let buyer;
  let addrs;

  beforeEach(async function () {
    // Obtener las cuentas de prueba
    [owner, creator, buyer, ...addrs] = await ethers.getSigners();

    // Desplegar el contrato
    StudyGuideNFT = await ethers.getContractFactory("StudyGuideNFT");
    studyGuideNFT = await StudyGuideNFT.deploy();
    await studyGuideNFT.waitForDeployment();
  });

  describe("Creación de guías", function () {
    it("Debería crear una nueva guía correctamente", async function () {
      const title = "Guía de Matemáticas";
      const author = "Juan Pérez";
      const description = "Guía completa de álgebra";
      const subject = "Matemáticas";
      const price = ethers.parseEther("0.1");
      const totalSupply = 100;
      const royaltyPercentage = 500; // 5%
      const uri = "ipfs://QmTest";

      await expect(
        studyGuideNFT.connect(creator).createGuide(
          title,
          author,
          description,
          subject,
          price,
          totalSupply,
          royaltyPercentage,
          uri
        )
      )
        .to.emit(studyGuideNFT, "GuideCreated")
        .withArgs(1, creator.address, title, price, totalSupply);

      const guideInfo = await studyGuideNFT.getGuideInfo(1);
      expect(guideInfo.title).to.equal(title);
      expect(guideInfo.author).to.equal(author);
      expect(guideInfo.price).to.equal(price);
      expect(guideInfo.totalSupply).to.equal(totalSupply);
    });

    it("No debería permitir crear una guía con precio 0", async function () {
      await expect(
        studyGuideNFT.connect(creator).createGuide(
          "Título",
          "Autor",
          "Descripción",
          "Materia",
          0,
          100,
          500,
          "ipfs://QmTest"
        )
      ).to.be.revertedWith("El precio debe ser mayor que 0");
    });
  });

  describe("Compra de guías", function () {
    beforeEach(async function () {
      // Crear una guía para las pruebas de compra
      await studyGuideNFT.connect(creator).createGuide(
        "Guía de Test",
        "Autor Test",
        "Descripción Test",
        "Materia Test",
        ethers.parseEther("0.1"),
        100,
        500,
        "ipfs://QmTest"
      );
    });

    it("Debería permitir comprar una guía correctamente", async function () {
      const price = ethers.parseEther("0.1");
      
      await expect(
        studyGuideNFT.connect(buyer).purchaseGuide(1, { value: price })
      )
        .to.emit(studyGuideNFT, "GuidePurchased")
        .withArgs(1, buyer.address, 1, price);

      const balance = await studyGuideNFT.balanceOf(buyer.address, 1);
      expect(balance).to.equal(1);
    });

    it("No debería permitir comprar con pago insuficiente", async function () {
      const price = ethers.parseEther("0.05"); // Menos del precio requerido
      
      await expect(
        studyGuideNFT.connect(buyer).purchaseGuide(1, { value: price })
      ).to.be.revertedWith("Pago insuficiente");
    });
  });

  describe("Funciones administrativas", function () {
    beforeEach(async function () {
      await studyGuideNFT.connect(creator).createGuide(
        "Guía de Test",
        "Autor Test",
        "Descripción Test",
        "Materia Test",
        ethers.parseEther("0.1"),
        100,
        500,
        "ipfs://QmTest"
      );
    });

    it("Debería permitir al owner actualizar una guía", async function () {
      const newPrice = ethers.parseEther("0.2");
      
      await expect(
        studyGuideNFT.connect(owner).updateGuide(1, newPrice, false)
      )
        .to.emit(studyGuideNFT, "GuideUpdated")
        .withArgs(1, newPrice, false);

      const guideInfo = await studyGuideNFT.getGuideInfo(1);
      expect(guideInfo.price).to.equal(newPrice);
      expect(guideInfo.isAvailable).to.equal(false);
    });

    it("No debería permitir a no-owners actualizar una guía", async function () {
      await expect(
        studyGuideNFT.connect(buyer).updateGuide(1, ethers.parseEther("0.2"), false)
      ).to.be.revertedWithCustomError(studyGuideNFT, "OwnableUnauthorizedAccount");
    });
  });

  describe("Funciones de quema", function () {
    beforeEach(async function () {
      await studyGuideNFT.connect(creator).createGuide(
        "Guía de Test",
        "Autor Test",
        "Descripción Test",
        "Materia Test",
        ethers.parseEther("0.1"),
        100,
        500,
        "ipfs://QmTest"
      );
      
      await studyGuideNFT.connect(buyer).purchaseGuide(1, { value: ethers.parseEther("0.1") });
    });

    it("Debería permitir quemar tokens", async function () {
      await expect(
        studyGuideNFT.connect(buyer).burn(1, 1)
      )
        .to.emit(studyGuideNFT, "GuideBurned")
        .withArgs(1, buyer.address, 1);

      const balance = await studyGuideNFT.balanceOf(buyer.address, 1);
      expect(balance).to.equal(0);
    });

    it("No debería permitir quemar más tokens de los que se poseen", async function () {
      await expect(
        studyGuideNFT.connect(buyer).burn(1, 2)
      ).to.be.revertedWith("Saldo insuficiente");
    });
  });

  describe("Funciones de pausa", function () {
    it("Debería permitir al owner pausar el contrato", async function () {
      await studyGuideNFT.connect(owner).setPaused(true);
      
      await expect(
        studyGuideNFT.connect(creator).createGuide(
          "Guía de Test",
          "Autor Test",
          "Descripción Test",
          "Materia Test",
          ethers.parseEther("0.1"),
          100,
          500,
          "ipfs://QmTest"
        )
      ).to.be.revertedWithCustomError(studyGuideNFT, "EnforcedPause");
    });
  });
}); 