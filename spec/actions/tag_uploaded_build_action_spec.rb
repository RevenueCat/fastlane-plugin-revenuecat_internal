describe Fastlane::Actions::TagUploadedBuildAction do
  describe '#run' do
    it 'calls the helper with the appropriate parameters' do
      expect(Fastlane::Helper::AppReleaseTrainHelper).to receive(:tag_uploaded_build)
        .with('1.2.3', 456)
        .once

      Fastlane::Actions::TagUploadedBuildAction.run(
        version: '1.2.3',
        build_number: 456
      )
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::TagUploadedBuildAction.available_options.size).to eq(2)
    end
  end
end
