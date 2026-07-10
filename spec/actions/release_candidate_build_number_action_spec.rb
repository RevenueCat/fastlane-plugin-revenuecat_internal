describe Fastlane::Actions::ReleaseCandidateBuildNumberAction do
  describe '#run' do
    it 'calls the helper with the appropriate parameters' do
      expect(Fastlane::Helper::AppReleaseTrainHelper).to receive(:release_candidate_build_number)
        .with('1.2.3', 'main')
        .and_return(456)
        .once

      build_number = Fastlane::Actions::ReleaseCandidateBuildNumberAction.run(
        version: '1.2.3',
        main_branch: 'main'
      )
      expect(build_number).to eq(456)
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::ReleaseCandidateBuildNumberAction.available_options.size).to eq(2)
    end
  end
end
