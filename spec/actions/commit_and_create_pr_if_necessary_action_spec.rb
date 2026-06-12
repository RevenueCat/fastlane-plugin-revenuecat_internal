describe Fastlane::Actions::CommitAndCreatePrIfNecessaryAction do
  describe '#run' do
    it 'calls appropriate helper method with expected parameters' do
      expect(Fastlane::Helper::CommitAndPrHelper).to receive(:commit_push_and_create_pr_if_necessary).with(
        'commit message',
        'update-error-codes',
        'PR title',
        'PR body',
        'purchases-ios',
        'main',
        'fake-github-token',
        'pr:other,auto:codegen',
        'coresdk',
        'src/generated/error-codes.ts,api-report'
      ).once

      Fastlane::Actions::CommitAndCreatePrIfNecessaryAction.run(
        commit_message: 'commit message',
        branch_name: 'update-error-codes',
        title: 'PR title',
        body: 'PR body',
        repo_name: 'purchases-ios',
        base_branch: 'main',
        github_pr_token: 'fake-github-token',
        labels: 'pr:other,auto:codegen',
        team_reviewers: 'coresdk',
        commit_paths: 'src/generated/error-codes.ts,api-report'
      )
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::CommitAndCreatePrIfNecessaryAction.available_options.size).to eq(10)
    end
  end
end
