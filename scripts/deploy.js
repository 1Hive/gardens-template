const deployTemplate = require('@aragon/templates-shared/scripts/deploy-template')

const TEMPLATE_NAME = 'gardens-template'
const CONTRACT_NAME = 'GardensTemplate'

module.exports = (callback) => {
  deployTemplate(web3, artifacts, TEMPLATE_NAME, CONTRACT_NAME)
    .then(template => {
      console.log("Gardens Template address: ", template.address)
    })
    .catch(error => console.log(error))
    .finally(callback)
}
