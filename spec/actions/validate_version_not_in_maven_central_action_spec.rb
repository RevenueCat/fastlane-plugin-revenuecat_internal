describe Fastlane::Actions::ValidateVersionNotInMavenCentralAction do
  describe '#run' do
    let(:group_id) { 'com.revenuecat.purchases' }
    let(:artifact_ids) { ['purchases', 'purchases-ui'] }
    let(:version) { '7.0.0' }
    let(:auth_token) { 'test-token' }
    let(:base_url) { 'https://central.sonatype.com/api/v1/publisher/published' }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("FETCH_PUBLICATIONS_USER_TOKEN_MAVEN_CENTRAL").and_return(auth_token)
    end

    context 'when version does not exist in Maven Central' do
      before do
        artifact_ids.each do |artifact_id|
          # Use a more flexible URL pattern that matches regardless of parameter order
          stub_request(:get, /#{Regexp.escape(base_url)}/)
            .with(
              query: hash_including({
                'namespace' => group_id,
                'name' => artifact_id,
                'version' => version
              })
            )
            .to_return(status: 200, body: { "published" => false }.to_json)
        end
      end

      it 'succeeds and shows success message' do
        expect(FastlaneCore::UI).to receive(:message).with("Checking if version #{version} already exists in Maven Central...")
        expect(FastlaneCore::UI).to receive(:message).with("Found #{artifact_ids.length} artifacts to check: #{artifact_ids.join(', ')}")
        expect(FastlaneCore::UI).to receive(:success).with("Version #{version} does not exist in Maven Central. Proceeding with deployment.")

        described_class.run({
          group_id: group_id,
          artifact_ids: artifact_ids,
          version: version,
          auth_token: auth_token
        })
      end
    end

    context 'when version exists for some artifacts in Maven Central' do
      before do
        # First artifact exists
        stub_request(:get, /#{Regexp.escape(base_url)}/)
          .with(
            query: hash_including({
              'namespace' => group_id,
              'name' => artifact_ids[0],
              'version' => version
            })
          )
          .to_return(status: 200, body: { "published" => true }.to_json)

        # Second artifact doesn't exist
        stub_request(:get, /#{Regexp.escape(base_url)}/)
          .with(
            query: hash_including({
              'namespace' => group_id,
              'name' => artifact_ids[1],
              'version' => version
            })
          )
          .to_return(status: 200, body: { "published" => false }.to_json)
      end

      it 'fails with detailed error message' do
        expect(FastlaneCore::UI).to receive(:message).with("Checking if version #{version} already exists in Maven Central...")
        expect(FastlaneCore::UI).to receive(:message).with("Found #{artifact_ids.length} artifacts to check: #{artifact_ids.join(', ')}")
        expect(FastlaneCore::UI).to receive(:important).with("Artifact #{group_id}:#{artifact_ids[0]}:#{version} already exists in Maven Central")

        expected_error = "Version #{version} already exists in Maven Central for the following artifacts:\n  " \
                         "- #{group_id}:#{artifact_ids[0]}:#{version}\n" \
                         "\nDeployment cancelled to prevent duplicate releases."

        expect(FastlaneCore::UI).to receive(:user_error!).with(expected_error).and_raise(StandardError.new("Version exists"))

        expect do
          described_class.run({
            group_id: group_id,
            artifact_ids: artifact_ids,
            version: version,
            auth_token: auth_token
          })
        end.to raise_error(StandardError, "Version exists")
      end
    end

    context 'when all versions exist in Maven Central' do
      before do
        artifact_ids.each do |artifact_id|
          stub_request(:get, /#{Regexp.escape(base_url)}/)
            .with(
              query: hash_including({
                'namespace' => group_id,
                'name' => artifact_id,
                'version' => version
              })
            )
            .to_return(status: 200, body: { "published" => true }.to_json)
        end
      end

      it 'fails with detailed error message listing all artifacts' do
        expect(FastlaneCore::UI).to receive(:message).with("Checking if version #{version} already exists in Maven Central...")
        expect(FastlaneCore::UI).to receive(:message).with("Found #{artifact_ids.length} artifacts to check: #{artifact_ids.join(', ')}")

        artifact_ids.each do |artifact_id|
          expect(FastlaneCore::UI).to receive(:important).with("Artifact #{group_id}:#{artifact_id}:#{version} already exists in Maven Central")
        end

        expected_error = "Version #{version} already exists in Maven Central for the following artifacts:\n  " \
                         "- #{group_id}:#{artifact_ids[0]}:#{version}\n  " \
                         "- #{group_id}:#{artifact_ids[1]}:#{version}\n" \
                         "\nDeployment cancelled to prevent duplicate releases."

        expect(FastlaneCore::UI).to receive(:user_error!).with(expected_error).and_raise(StandardError.new("All versions exist"))

        expect do
          described_class.run({
            group_id: group_id,
            artifact_ids: artifact_ids,
            version: version,
            auth_token: auth_token
          })
        end.to raise_error(StandardError, "All versions exist")
      end
    end

    context 'when auth token is missing' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("FETCH_PUBLICATIONS_USER_TOKEN_MAVEN_CENTRAL").and_return(nil)
      end

      it 'fails with authentication error' do
        expect(FastlaneCore::UI).to receive(:message).with("Checking if version #{version} already exists in Maven Central...")
        expect(FastlaneCore::UI).to receive(:message).with("Found #{artifact_ids.length} artifacts to check: #{artifact_ids.join(', ')}")
        expect(FastlaneCore::UI).to receive(:user_error!).with("FETCH_PUBLICATIONS_USER_TOKEN_MAVEN_CENTRAL environment variable is not set. Please provide a valid token to check Maven Central publications.").and_raise(StandardError.new("Authentication failed"))

        expect do
          described_class.run({
            group_id: group_id,
            artifact_ids: artifact_ids,
            version: version
          })
        end.to raise_error(StandardError, "Authentication failed")
      end
    end

    context 'when empty auth token is provided' do
      it 'fails with authentication error' do
        expect(FastlaneCore::UI).to receive(:message).with("Checking if version #{version} already exists in Maven Central...")
        expect(FastlaneCore::UI).to receive(:message).with("Found #{artifact_ids.length} artifacts to check: #{artifact_ids.join(', ')}")
        expect(FastlaneCore::UI).to receive(:user_error!).with("FETCH_PUBLICATIONS_USER_TOKEN_MAVEN_CENTRAL environment variable is not set. Please provide a valid token to check Maven Central publications.").and_raise(StandardError.new("Authentication failed"))

        expect do
          described_class.run({
            group_id: group_id,
            artifact_ids: artifact_ids,
            version: version,
            auth_token: ''
          })
        end.to raise_error(StandardError, "Authentication failed")
      end
    end

    context 'when no artifact IDs are provided' do
      it 'fails with validation error' do
        expect(FastlaneCore::UI).to receive(:message).with("Checking if version #{version} already exists in Maven Central...")
        expect(FastlaneCore::UI).to receive(:user_error!).with("No artifacts provided. Please provide at least one artifact ID to check").and_raise(StandardError.new("Validation failed"))

        expect do
          described_class.run({
            group_id: group_id,
            artifact_ids: [],
            version: version,
            auth_token: auth_token
          })
        end.to raise_error(StandardError, "Validation failed")
      end
    end

    context 'when API request fails' do
      before do
        # First artifact fails
        stub_request(:get, /#{Regexp.escape(base_url)}/)
          .with(
            query: hash_including({
              'namespace' => group_id,
              'name' => artifact_ids[0],
              'version' => version
            })
          )
          .to_raise(StandardError.new("Network error"))

        # Second artifact should not be reached due to first failure, but add stub just in case
        stub_request(:get, /#{Regexp.escape(base_url)}/)
          .with(
            query: hash_including({
              'namespace' => group_id,
              'name' => artifact_ids[1],
              'version' => version
            })
          )
          .to_return(status: 200, body: { "published" => false }.to_json)
      end

      it 'fails with API error message' do
        expect(FastlaneCore::UI).to receive(:message).with("Checking if version #{version} already exists in Maven Central...")
        expect(FastlaneCore::UI).to receive(:message).with("Found #{artifact_ids.length} artifacts to check: #{artifact_ids.join(', ')}")
        expect(FastlaneCore::UI).to receive(:user_error!).with("Failed to check #{group_id}:#{artifact_ids[0]}:#{version}: Network error").and_raise(StandardError.new("API error"))

        expect do
          described_class.run({
            group_id: group_id,
            artifact_ids: artifact_ids,
            version: version,
            auth_token: auth_token
          })
        end.to raise_error(StandardError, "API error")
      end
    end
  end

  describe '.description' do
    it 'returns the correct description' do
      expect(described_class.description).to eq("Checks if a specific version of Maven artifacts already exists in Maven Central before deployment")
    end
  end

  describe '.available_options' do
    it 'returns the correct options' do
      options = described_class.available_options
      expect(options).to be_an(Array)
      expect(options.length).to eq(4)

      group_id_option = options.find { |opt| opt.key == :group_id }
      expect(group_id_option).not_to be_nil
      expect(group_id_option.optional).to be false
      expect(group_id_option.data_type).to eq(String)

      artifact_ids_option = options.find { |opt| opt.key == :artifact_ids }
      expect(artifact_ids_option).not_to be_nil
      expect(artifact_ids_option.optional).to be false
      expect(artifact_ids_option.data_type).to eq(Array)

      version_option = options.find { |opt| opt.key == :version }
      expect(version_option).not_to be_nil
      expect(version_option.optional).to be false
      expect(version_option.data_type).to eq(String)

      auth_token_option = options.find { |opt| opt.key == :auth_token }
      expect(auth_token_option).not_to be_nil
      expect(auth_token_option.optional).to be true
      expect(auth_token_option.data_type).to eq(String)
    end
  end

  describe '.is_supported?' do
    it 'returns true for all platforms' do
      expect(described_class.is_supported?(:ios)).to be true
      expect(described_class.is_supported?(:android)).to be true
      expect(described_class.is_supported?(:mac)).to be true
    end
  end
end
