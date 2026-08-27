import { defineConfig } from 'vitepress';

export default defineConfig({
  base: '/amounts/',
  title: 'amounts',
  description: 'Precise fungible quantities for Ruby and Rails',
  lang: 'en-US',
  cleanUrls: true,
  lastUpdated: true,
  appearance: false,
  vite: {
    server: {
      allowedHosts: true,
    },
  },
  themeConfig: {
    siteTitle: 'amounts',
    search: {
      provider: 'local',
    },
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Quick Start', link: '/getting-started/' },
      { text: 'Concepts', link: '/concepts/atomic-vs-ui' },
      { text: 'Guides', link: '/guides/register-a-token' },
      { text: 'Rails', link: '/rails/overview' },
      { text: 'Testing', link: '/testing/overview' },
      { text: 'Design', link: '/design/decisions' },
      { text: 'Reference', link: '/reference/api' },
    ],
    sidebar: [
      {
        text: 'Introduction',
        items: [
          { text: 'Home', link: '/' },
          { text: 'Quick Start', link: '/getting-started/' },
        ],
      },
      {
        text: 'Concepts',
        items: [
          { text: 'Atomic vs UI', link: '/concepts/atomic-vs-ui' },
          { text: 'Registry and Types', link: '/concepts/registry-and-types' },
          { text: 'Rates and Conversion', link: '/concepts/rates-and-conversion' },
          { text: 'Display and Units', link: '/concepts/display-and-units' },
          { text: 'Splitting and Allocation', link: '/concepts/splitting-and-allocation' },
          { text: 'Serialization', link: '/concepts/serialization' },
        ],
      },
      {
        text: 'Guides',
        items: [
          { text: 'Register a Token', link: '/guides/register-a-token' },
          { text: 'Parse Client Input', link: '/guides/parse-client-input' },
          { text: 'Cross-Type Arithmetic', link: '/guides/cross-type-arithmetic' },
          { text: 'Rails Persistence', link: '/guides/rails-persistence' },
        ],
      },
      {
        text: 'Rails',
        items: [
          { text: 'Overview', link: '/rails/overview' },
          { text: 'Registry Generator', link: '/rails/registry-generator' },
          { text: 'Migration DSL', link: '/rails/migration-dsl' },
          { text: 'has_amount', link: '/rails/has-amount' },
          { text: 'Querying', link: '/rails/querying' },
          { text: 'Database Notes', link: '/rails/database-notes' },
        ],
      },
      {
        text: 'Testing',
        items: [
          { text: 'Overview', link: '/testing/overview' },
          { text: 'RSpec Matchers', link: '/testing/rspec-matchers' },
          { text: 'Minitest', link: '/testing/minitest' },
        ],
      },
      {
        text: 'Cookbook',
        items: [
          { text: 'Orbit Treasury', link: '/cookbook/orbit-treasury' },
          { text: 'Auric Vault', link: '/cookbook/auric-vault' },
          { text: 'Timber Yard', link: '/cookbook/timber-yard' },
          { text: 'Ember Exchange', link: '/cookbook/ember-exchange' },
        ],
      },
      {
        text: 'Design',
        items: [
          { text: 'Design Decisions', link: '/design/decisions' },
          { text: 'Compared to Alternatives', link: '/design/comparisons' },
        ],
      },
      {
        text: 'Reference',
        items: [
          { text: 'API Reference', link: '/reference/api' },
        ],
      },
    ],
    socialLinks: [{ icon: 'github', link: 'https://github.com/zarpay/amounts' }],
    outline: {
      level: [2, 3],
      label: 'On this page',
    },
    docFooter: {
      prev: 'Previous page',
      next: 'Next page',
    },
    footer: {
      message: 'Built for precise money, token, commodity, and inventory workflows.',
      copyright: 'Released under the MIT License',
    },
  },
});
