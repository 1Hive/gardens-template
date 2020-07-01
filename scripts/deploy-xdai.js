const deployTemplate = require('@aragon/templates-shared/scripts/deploy-template')

const TEMPLATE_NAME = 'gardens-template'
const CONTRACT_NAME = 'GardensTemplate'
const ENS = '0xaafca6b0c89521752e559650206d7c925fd0e530'
const DAO_FACTORY = '0x4037f97fcc94287257e50bd14c7da9cb4df18250'
const MINIME = '0xf7d36d4d46cda364edc85e5561450183469484c5'

module.exports = (callback) => {
  deployTemplate(web3, artifacts, TEMPLATE_NAME, CONTRACT_NAME, ens=ENS, daoFactory=DAO_FACTORY, miniMeFactory=MINIME )
    .then(template => {
      console.log("Gardens Template address: ", template.address)
    })
    .catch(error => console.log(error))
    .finally(callback)
}
