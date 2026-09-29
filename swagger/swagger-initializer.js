window.onload = function () {
  window.ui = SwaggerUIBundle({
    urls: [
      {
        name: "Chabok IAM API",
        url: "/openapi/v1/iam.yaml",
      },
      {
        name: "Chabok Consignment API",
        url: "/openapi/v1/consignments.yaml",
      },
      {
        name: "Chabok Manifest API",
        url: "/openapi/v1/manifests.yaml",
      },
      {
        name: "Chabok Dashboard API",
        url: "/openapi/v1/dashboard.yaml",
      },
      {
        name: "Chabok Service Catalog API",
        url: "/openapi/v1/service-catalog.yaml",
      },
      {
        name: "Chabok Pricing API",
        url: "/openapi/v1/pricing.yaml",
      },
      {
        name: "Chabok Geography Reference API",
        url: "/openapi/v1/geography.yaml",
      },
      {
        name: "Chabok Operations API",
        url: "/openapi/v1/operations.yaml",
      },
      {
        name: "Chabok Network Administration API",
        url: "/openapi/v1/network.yaml",
      },
      {
        name: "Chabok Fleet Administration API",
        url: "/openapi/v1/fleet.yaml",
      },
      {
        name: "Chabok CRM API",
        url: "/openapi/v1/crm.yaml",
      },
    ],
    "urls.primaryName": "Chabok IAM API",
    dom_id: "#swagger-ui",
    deepLinking: true,
    displayOperationId: true,
    filter: true,
    persistAuthorization: false,
    showExtensions: true,
    validatorUrl: null,
    withCredentials: true,
    presets: [
      SwaggerUIBundle.presets.apis,
      SwaggerUIStandalonePreset,
    ],
    plugins: [
      SwaggerUIBundle.plugins.DownloadUrl,
    ],
    layout: "StandaloneLayout",
  });
};
