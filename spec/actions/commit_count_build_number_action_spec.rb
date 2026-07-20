describe Fastlane::Actions::CommitCountBuildNumberAction do
  describe '#run' do
    it 'returns the helper-computed build number' do
      expect(Fastlane::Helper::AppReleaseTrainHelper).to receive(:commit_count_build_number)
        .and_return(1234)
        .once

      expect(Fastlane::Actions::CommitCountBuildNumberAction.run({})).to eq(1234)
    end
  end

  describe '#available_options' do
    it 'has no options' do
      expect(Fastlane::Actions::CommitCountBuildNumberAction.available_options.size).to eq(0)
    end
  end
end
