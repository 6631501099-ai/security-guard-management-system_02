const accountRoutes = require("../Project/accounts/accounts.routes");
const securityguardmanagementsystemRoutes = require("../Project/securityguardmanagementsystem/securityguardmanagementsystem.routes");
const securityRoutes = require("../Project/security/security.routes");
const settingsRoutes = require("../Project/settings/settings.routes");

module.exports = function (app) {
  const path = "/api/v1";

  app.use(path + '/securityguardmanagementsystem', securityguardmanagementsystemRoutes);
  app.use(path + '/setting', settingsRoutes);
  app.use(path + '/security', securityRoutes);
  app.use(path, accountRoutes);
};
