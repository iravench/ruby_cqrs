require_relative('../../../spec_helper')

describe RubyCqrs::Domain::AggregateRepository do
  let(:unsorted_event_records) { [
    { :aggregate_id => SomeDomain::AGGREGATE_ID,
      :event_type => SomeDomain::SecondEvent.name,
      :version => 2,
      :data => '' },
    { :aggregate_id => SomeDomain::AGGREGATE_ID,
      :event_type => SomeDomain::FirstEvent.name,
      :version => 1,
      :data => '' } ] }
  let(:aggregate_id) { SomeDomain::AGGREGATE_ID }
  let(:event_store_load_result) { { :aggregate_id => aggregate_id,
                                    :aggregate_type => 'SomeDomain::AggregateRoot',
                                    :events => unsorted_event_records } }
  let(:event_store) do
    _event_store = (Class.new { include RubyCqrs::Data::EventStore}).new
    allow(_event_store).to receive(:load_by).and_return(event_store_load_result)
    _event_store
  end
  let(:command_context) { Object.new }
  let(:repository) { RubyCqrs::Domain::AggregateRepository.new event_store, command_context }
  let(:aggregate_type) { SomeDomain::AggregateRoot }

  describe '#find_by' do
    it "delegates the actual data loading to the EventStore instance's #load_by" do
      expect(event_store).to receive(:load_by) do |some_guid, some_command_context|
        expect(some_guid).to be_a_valid_uuid
        expect(some_command_context).to be(command_context)
      end.and_return event_store_load_result

      repository.find_by(aggregate_id)
    end

    context 'when the specified aggregate could not be found' do
      let(:empty_event_store) do
        _event_store = (Class.new { include RubyCqrs::Data::EventStore}).new
        allow(_event_store).to receive(:load_by).and_return(nil)
        _event_store
      end
      let(:matches_nothing_repository) { RubyCqrs::Domain::AggregateRepository.new\
                                         empty_event_store, command_context }

      it 'raises error of type AggregateNotFoundError' do
        expect { matches_nothing_repository.find_by(aggregate_id) }.to \
          raise_error(RubyCqrs::AggregateNotFoundError)
      end
    end

    context 'when the specified aggregate is found' do
      let(:aggregate) { repository.find_by(aggregate_id) }
      let(:expeced_version) { unsorted_event_records.size }
      let(:expeced_source_version) { unsorted_event_records.size }

      it 'returns an instance of expected type' do
        expect(aggregate).to be_an_instance_of(aggregate_type)
      end

      it 'returns an instance of expected aggregate_id' do
        expect(aggregate.aggregate_id).to eq(aggregate_id)
      end

      it 'returns an instance of expected version' do
        expect(aggregate.version).to eq(expeced_version)
      end

      it 'returns an instance of expected source_version' do
        expect(aggregate.instance_variable_get(:@source_version)).to eq(expeced_source_version)
      end
    end
  end

  describe '#save' do
    describe 'during the saving process' do
      context 'when saving a single aggregate' do
        context 'when the aggregate has not been changed' do
          let(:unchanged_aggregate) do
            aggregate_type.new
          end

          it "short-circuit without calling the EventStore instance's #save" do
            expect(event_store).to_not receive(:save)
            repository.save unchanged_aggregate
          end
        end

        context 'when the aggregate has been changed' do
          let(:changed_aggregate) do
            _aggregate = aggregate_type.new
            _aggregate.test_fire
            _aggregate.test_fire_ag
            _aggregate
          end

          it "delegates event persistence to the EventStore instance's #save" do
            expect(event_store).to receive(:save) do |aggregate_changes, some_command_context|
              expect(aggregate_changes.size).to eq(1)
              expect(aggregate_changes[0][:aggregate_id]).to eq(changed_aggregate.aggregate_id)
              expect(aggregate_changes[0][:aggregate_type]).to eq(changed_aggregate.class.name)
              expect(aggregate_changes[0][:events].size).to eq(2)
              expect(aggregate_changes[0][:events][0][:aggregate_id]).to eq(changed_aggregate.aggregate_id)
              expect(aggregate_changes[0][:events][0][:version]).to eq(1)
              expect(aggregate_changes[0][:events][0][:event_type]).to eq(SomeDomain::ThirdEvent.name)
              expect(aggregate_changes[0][:events][0][:data]).to_not be_nil
              expect(aggregate_changes[0][:events][1][:aggregate_id]).to eq(changed_aggregate.aggregate_id)
              expect(aggregate_changes[0][:events][1][:version]).to eq(2)
              expect(aggregate_changes[0][:events][1][:event_type]).to eq(SomeDomain::ForthEvent.name)
              expect(aggregate_changes[0][:events][1][:data]).to_not be_nil
              expect(some_command_context).to be(command_context)
            end

            repository.save(changed_aggregate)
          end

          describe 'after the saving process finished successfully' do
            it 'has both version and source_version set to the same value' do
              expect(event_store).to receive(:save)

              repository.save(changed_aggregate)

              expect(changed_aggregate.version).to eq(2)
              expect(changed_aggregate.instance_variable_get(:@source_version)).to eq(2)
            end
          end

          describe 'if some error happened during the saving process' do
            before(:each) do
              expect(event_store).to receive(:save) { raise RubyCqrs::AggregateConcurrencyError }
            end

            it 'bubbles up that error directly' do
              expect { repository.save(changed_aggregate) }.to\
                raise_error(RubyCqrs::AggregateConcurrencyError)
            end

            it 'has source_version unchanged' do
              original_source_version = changed_aggregate.instance_variable_get(:@source_version)

              expect { repository.save(changed_aggregate) }.to\
                raise_error(RubyCqrs::AggregateConcurrencyError)

              expect(changed_aggregate.instance_variable_get(:@source_version)).to eq(original_source_version)
            end
          end
        end
      end

      context 'when saving 2 instances of the same aggregate' do
        it 'raises AggregateDuplicationError and nothing should be changed' do
          aggregate_1 = aggregate_type.new
          aggregate_2 = aggregate_1.dup
          aggregate_1.test_fire
          aggregate_2.test_fire
          aggregates = [ aggregate_1, aggregate_2 ]
          expect{ repository.save aggregates }.to raise_error(RubyCqrs::AggregateDuplicationError)
          expect(aggregate_1.version).to_not eq(aggregate_1.instance_variable_get(:@source_verrsion))
          expect(aggregate_2.version).to_not eq(aggregate_2.instance_variable_get(:@source_verrsion))
        end
      end

      context 'when saving 2 aggregates' do
        context 'when none of the aggregates have been changed' do
          let(:unchanged_aggregates) do
            [ aggregate_type.new, aggregate_type.new ]
          end

          it "short-circuit without calling the EventStore instance's #save" do
            expect(event_store).to_not receive(:save)
            repository.save unchanged_aggregates
          end
        end

        context 'when one of the aggregates has been changed' do
          let(:two_aggregates) do
            _aggregate = aggregate_type.new
            _aggregate.test_fire
            _aggregate.test_fire_ag
            [ _aggregate, aggregate_type.new ]
          end

          it "delegates event persistence to the EventStore instance's #save" do
            expect(event_store).to receive(:save) do |aggregate_changes, some_command_context|
              expect(aggregate_changes.size).to eq(1)
              expect(some_command_context).to be(command_context)
            end

            repository.save(two_aggregates)
          end

          describe 'the aggregate that changed, after the saving process finished successfully' do
            it 'has both version and source_version set to the same value' do
              expect(event_store).to receive(:save)

              repository.save(two_aggregates)

              expect(two_aggregates[0].version).to eq(2)
              expect(two_aggregates[0].instance_variable_get(:@source_version)).to eq(2)
            end
          end

          describe 'the aggregate that did not change, after the saving process finished successfully' do
            it 'has both version and source_version unchanged' do
              expect(event_store).to receive(:save)
              original_version = two_aggregates[1].version
              original_source_version = two_aggregates[1].instance_variable_get(:@source_version)

              repository.save(two_aggregates)

              expect(two_aggregates[1].version).to eq(original_version)
              expect(two_aggregates[1].instance_variable_get(:@source_version)).to eq(original_source_version)
            end
          end

          describe 'if some error happened during the saving process' do
            before(:each) do
              expect(event_store).to receive(:save) { raise RubyCqrs::AggregateConcurrencyError }
            end

            it 'bubbles up that error directly' do
              expect { repository.save(two_aggregates) }.to\
                raise_error(RubyCqrs::AggregateConcurrencyError)
            end

            it 'has source_version unchanged' do
              original_source_version_0 = two_aggregates[0].instance_variable_get(:@source_version)
              original_source_version_1 = two_aggregates[1].instance_variable_get(:@source_version)

              expect { repository.save(two_aggregates) }.to\
                raise_error(RubyCqrs::AggregateConcurrencyError)

              expect(two_aggregates[0].instance_variable_get(:@source_version)).to eq(original_source_version_0)
              expect(two_aggregates[1].instance_variable_get(:@source_version)).to eq(original_source_version_1)
            end
          end
        end

        context 'when both aggregates have been changed' do
          let(:two_aggregates) do
            _aggregate_1 = aggregate_type.new
            _aggregate_2 = aggregate_type.new
            _aggregate_1.test_fire
            _aggregate_1.test_fire_ag
            _aggregate_2.test_fire
            _aggregate_2.test_fire_ag
            [ _aggregate_2, _aggregate_1 ]
          end

          it "delegates event persistence to the EventStore instance's #save" do
            expect(event_store).to receive(:save) do |aggregate_changes, some_command_context|
              expect(aggregate_changes.size).to eq(2)
              expect(some_command_context).to be(command_context)
            end

            repository.save(two_aggregates)
          end

          describe 'after the saving process finished successfully' do
            it "has both aggregates' version and source_version set to the same value" do
              expect(event_store).to receive(:save)

              repository.save(two_aggregates)

              expect(two_aggregates[0].version).to eq(2)
              expect(two_aggregates[0].instance_variable_get(:@source_version)).to eq(2)
              expect(two_aggregates[1].version).to eq(2)
              expect(two_aggregates[1].instance_variable_get(:@source_version)).to eq(2)
            end
          end

          describe 'if something wrong happened during the saving process' do
            before(:each) do
              expect(event_store).to receive(:save) { raise RubyCqrs::AggregateConcurrencyError }
            end

            it 'bubbles up that error directly' do
              expect { repository.save(two_aggregates) }.to\
                raise_error(RubyCqrs::AggregateConcurrencyError)
            end

            it 'has source_version unchanged' do
              original_source_version_0 = two_aggregates[0].instance_variable_get(:@source_version)
              original_source_version_1 = two_aggregates[1].instance_variable_get(:@source_version)

              expect { repository.save(two_aggregates) }.to\
                raise_error(RubyCqrs::AggregateConcurrencyError)

              expect(two_aggregates[0].instance_variable_get(:@source_version)).to eq(original_source_version_0)
              expect(two_aggregates[1].instance_variable_get(:@source_version)).to eq(original_source_version_1)
            end
          end
        end
      end
    end
  end
end
