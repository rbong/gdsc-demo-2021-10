module.exports = {
  swagger: "2.0",
  info: {
    title: "GDSC Demo API",
    version: "1.0.0"
  },
  // The host will later be filled in by Terraform
  host: "${host}",
  schemes: [
    "https"
  ],
  produces: [
    "application/json"
  ],
};
