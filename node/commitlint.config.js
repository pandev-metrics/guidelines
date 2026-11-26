/** @type {import('@commitlint/types').UserConfig} */
export default {
  parserPreset: {
    parserOpts: {
      // feature/PROJ-123 - Description
      headerPattern: /^(\w+)\/([A-Z]+-\d+)\s*-\s*(.+)$/,
      headerCorrespondence: ["type", "ticket", "subject"],
    },
  },
  rules: {
    "type-enum": [
      2,
      "always",
      [
        "feature",
        "fix",
        "bugfix",
        "hotfix",
        "refactor",
        "docs",
        "style",
        "test",
        "chore",
        "ci",
        "release",
      ],
    ],
    "type-case": [2, "always", "lower-case"],
    "type-empty": [2, "never"],
    "subject-empty": [2, "never"],
    "subject-max-length": [2, "always", 100],
    "header-max-length": [2, "always", 120],
    "scope-empty": [0],
    "subject-case": [0],
  },
};
