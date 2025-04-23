describe Fastlane::Actions::CreatePrIfNecessaryAction do
  describe '#run' do
    it 'calls appropriate helper method with expected parameters' do
      title = 'Test PR Title'
      body = 'Test PR Body'
      repo_name = 'test-repo'
      base_branch = 'main'
      head_branch = 'feature-branch'
      github_pr_token = 'fake-github-token'
      labels = %w[label1 label2]
      team_reviewers = %w[team1 team2]

      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_pr_if_necessary).with(
        title,
        body,
        repo_name,
        base_branch,
        head_branch,
        github_pr_token,
        labels,
        team_reviewers
      ).once

      Fastlane::Actions::CreatePrIfNecessaryAction.run(
        title: title,
        body: body,
        repo_name: repo_name,
        base_branch: base_branch,
        head_branch: head_branch,
        github_pr_token: github_pr_token,
        labels: labels,
        team_reviewers: team_reviewers
      )
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::CreatePrIfNecessaryAction.available_options.size).to eq(8)
    end
  end
end
