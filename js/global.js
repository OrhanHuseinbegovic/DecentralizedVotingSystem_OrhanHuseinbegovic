window.addEventListener("load", async function () {
    if (window.ethereum) {
        const address = localStorage.getItem("address");
        if (address) {
            window.provider = new ethers.BrowserProvider(window.ethereum);
            window.signer = await window.provider.getSigner();

            console.log("Signer successfully restored:", await window.signer.getAddress());
            // Reinitialize your contract or logic here
        } else {
            console.log("Address not found. Please reconnect your wallet.");
        }
    } else {
        console.error("Ethereum provider not found!");
    }
});
