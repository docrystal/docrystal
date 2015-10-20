namespace :elasticsearch do
  namespace :index do
    desc 'Create a new index with timestamp'

    task show: :environment do
      Shard.tap do |model|
        es = model.__elasticsearch__
        puts "# index: #{model.index_name}"
        puts "# aliases: #{es.client.indices.get_alias(index: model.index_name)}"
      end
    end

    task create: :environment do
      Shard.tap do |model|
        es = model.__elasticsearch__
        new_index_name = "#{model.index_name}-#{Time.current.strftime('%Y%m%d%H%M%S')}"

        puts "# create #{new_index_name}"
        es.create_index!(index: new_index_name)

        puts "# import #{new_index_name} from data sources"

        es.import(
          index: new_index_name,
          type: model.document_type,
          batch_size: 2000)

        puts "# switch index from #{new_index_name} to #{model.index_name}"

        if es.client.indices.exists?(index: model.index_name)
          # ensure to remove the default index
          es.client.indices.delete(index: model.index_name)
        end

        actions = []
        actions << { add: { index: new_index_name, alias: model.index_name } }
        es.client.indices.get_alias(index: model.index_name).keys.each do |old_index|
          actions << { remove: { index: old_index, alias: model.index_name } }
        end

        es.client.indices.update_aliases(body: { actions: actions })
      end
    end

    task cleanup: :environment do
      Shard.tap do |model|
        es = model.__elasticsearch__

        indexes = es.client.cat.indices(index: model.index_name + '-*', format: :json).map do |meta|
          meta['index']
        end

        indexes.sort!

        puts "# the latest index: #{indexes.pop}"

        indexes.each do |index|
          puts "# delete index: #{index}"
          es.client.indices.delete(index: index)
        end
      end
    end
  end
end
