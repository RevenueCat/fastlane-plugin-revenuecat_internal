describe Fastlane::Actions::TriggerActionInCircleCiAction do
  describe '#run' do
    let(:circle_token) { 'dummy_token' }
    let(:action) { 'deploy' }
    let(:repo_name) { 'example_repo' }
    let(:branch) { 'main' }
    let(:fake_url) { 'https://app.circleci.com/pipelines/github/RevenueCat/example_repo/1' }

    before do
      allow(Fastlane::UI).to receive(:important)
      stub_request(:post, "https://circleci.com/api/v2/project/github/RevenueCat/#{repo_name}/pipeline").
        with(
          body: hash_including(
            parameters: { 'action' => action },
            branch: branch
          ),
          headers: {
            'Circle-Token' => circle_token,
            'Content-Type' => 'application/json',
            'Accept' => 'application/json'
          }
        ).
        to_return(status: 201, body: { number: 1 }.to_json, headers: {})
    end

    it 'triggers a CircleCI pipeline and prints the workflow URL' do
      Fastlane::Actions::TriggerActionInCircleCiAction.run(
        circle_token: circle_token,
        action: action,
        repo_name: repo_name,
        branch: branch
      )

      expect(Fastlane::UI).to have_received(:important).with("Workflow: #{fake_url}")
    end

    it 'raises an error if the CIRCLE_TOKEN is not provided' do
      expect do
        Fastlane::Actions::TriggerActionInCircleCiAction.run(
          action: action,
          repo_name: repo_name,
          branch: branch
        )
      end.to raise_error("Please set the CIRCLE_TOKEN environment variable")
    end
  end
end
