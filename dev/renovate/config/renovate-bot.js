module.exports = {
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  // Replace this with your GitHub app name
  "username": "gmo-media-renovate[bot]",
  // Replace this with your GitHub app email
  // Get the account id from `https://api.github.com/users/<username>`.
  "gitAuthor": "gmo-media-renovate <227964276+gmo-media-renovate[bot]@users.noreply.github.com>",
  "repositories": [
    "gmo-media/infra-template",
    // Add more repositories here
  ],
  // Required for EKS addon datasource
  "allowedEnv": [
    "AWS_ACCESS_KEY_ID",
    "AWS_SECRET_ACCESS_KEY",
  ]
}
