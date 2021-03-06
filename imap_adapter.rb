require 'net/imap'

class ImapAdapter

  def initialize(options)
    @config = options
  end

  def select_box(box)
    connection.select(box)
  end

  def subscribe_box(box)
    connection.subscribe(box)
  end
  def unsubscribe_box(box)
    connection.unsubscribe(box)
  end

  def delete_box(box)
    connection.delete(box)
    reconnect
  end

  def select_or_create_box(box)
    begin
      select_box(box)
    rescue
      connection.create(box)
      select_box(box)
    end
  end

  def find_uids
    connection.uid_search(['ALL'])
  end

  def find_message_ids
    message_ids = []
    uids = find_uids
    if uids.any?
      each_slice(uids, ['ENVELOPE']) do |message|
        message_ids << message.attr['ENVELOPE'].message_id
      end
    end
    message_ids
  end

  def for_each_message
    uids = find_uids
    if uids.any?
      each_slice(uids, ['ENVELOPE']) do |message|
        yield message
      end
    end
  end

  def delete_messages(uid)
    connection.uid_store(uid, "+FLAGS", [:Deleted]) if uid
  end

  def copy_message(uid, server, folder)
    message = find_message(uid)
    server.append_message(message, folder)
  end

  def append_message(message, folder)
    connection.append(folder, message.attr['RFC822'], nil, message.attr['INTERNALDATE'])
  end

  def expunge
    connection.expunge
  end

  def disconnect
    connection.close unless connection.disconnected?()
    @connection = nil
  end

  def reconnect
    disconnect
    connection
  end

  private

  attr_reader :config

  def find_message(uid)
    connection.uid_fetch(uid, ['RFC822', 'FLAGS', 'INTERNALDATE']).first
  end

  def connection
    @connection ||= Net::IMAP.new(config['host'], config['port'], config['ssl'], nil, false).tap do |c|
      c.login(config['username'], config['password'])
      c.select('INBOX')
    end
  end

  def each_slice(uids, *args)
    uids.each_slice(500) do |slice|
      connection.uid_fetch(slice, *args).each {|message| yield message }
    end
  end
end
