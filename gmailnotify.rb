#!/usr/bin/env ruby 
#--coding:utf-8
require 'rubygems'
require 'xmpp4r'


module Jabber
  module GoogleNotify
    class Mailbox 
      def initialize(e)
        @node = e
      end
      def mail_threads
        threads = []
        @node.each_elements('mail-thread-info'){|e| threads.push  MailThread.new(e)}
        return threads
      end
    end
    class MailThread
      def initialize(e)
        @node = e
      end
      def subject
        @node.each_elements('subject'){|e| return e.text}
      end
      def url
        @node.attribute('url')
      end
      def unread
        @node.attribute('unread') == 1
      end
      def tid
        @node.attribute('tid')
      end
      def from 
        sender = @node.each_elements('senders/sender'){|e| e}.pop
        address = sender.attribute('address')
        name    = sender.attribute('name')
        return "#{name}<#{address}>"
      end
      def body_intro
        @node.each_elements('snippet'){|e| return e.text}
      end
    end
  end
  class Iq < XMPPStanza
    def is_new_mail?()
      self.elements.each('/new-mail'){}.size > 0 || self.elements.each('/new-mail'){}.size > 0
    end
    def is_new_mail_notify?()
      self.elements.each('/new-mail'){}.size > 0 || self.elements.each('/new-mail'){}.size > 0
    end
    def is_mailbox?()
      self.elements.each('/mailbox'){}.size > 0
    end
    def mailbox()
      e=nil
      self.elements.each('/mailbox'){|i|  e=i }
      return GoogleNotify::Mailbox.new e
    end
  end
  class Client
    def close
      self.close!
    end
    def close!
      @fd.close if @fd and !@fd.closed?
      @parser_thread.kill if @parser_thread and @parser_thread.alive?
      @status = DISCONNECTED
    end
  end
end

class GmailNotify
  @client
  @last_check = nil
  @username
  @password
  def initialize(username,password,debug=false)
    @last_check = Time.now
    @username,@password = username,password
    Jabber::debug = true if debug
    $stdout.sync  = true if debug
    $stderr.sync  = true if debug
  end
  def connect()
    jid = Jabber::JID.new(@username)
    @client = Jabber::Client.new(jid)
    @client.connect("talk.google.com")
    @client.auth(@password)
    self.send_new_mail_notify_request
    self.set_event_lisnter
    puts "connect called "
  end
  def send_new_mail_notify_request
    q = Jabber::IqQuery.new
    q.add_namespace('google:mail:notify')
    i = Jabber::Iq.new
    q.add_attribute("newer-than-time", @last_check.to_i) if @last_check
    i.type =:get
    i.to   = @username
    i.id="mail-request-1"
    i.add q
    @client.send(i)
  end
  def send_notify_accpept
    puts "send_notify_accept"
    q = Jabber::IqQuery.new
    q.add_namespace('google:mail:notify')
    i = Jabber::Iq.new
    i.type =:result
    i.to   = @username
    i.from = "#{@username}/orchard"
    i.id="mail-request-2"
    i.add q
    @client.send(i)
  end
  def send_new_mail_request
    puts "send_ new mail req"
    q = Jabber::IqQuery.new
    q.add_namespace('google:mail:notify')
    q.add_attribute("newer-than-time", @last_check.to_i) if @last_check
    i = Jabber::Iq.new
    i.type =:get
    i.to   = @username
    i.id="mail-request-2"
    i.add q
    @client.send(i)
    @last_check = Time.now
  end
  def set_event_lisnter()
    @client.add_iq_callback { |m|
      self.send_new_mail_request	if m.is_new_mail?
      self.notify(m.mailbox) if m.is_mailbox?
      puts m.to_s
    }
  end
  def start
      puts "trying to connect .."
      $stdout.flush
      self.connect
      while @client and @client.is_connected?
      	Thread.abort_on_exception = false
        sleep(10);
      end
      raise StandardError
    rescue SocketError  => e 
        puts "接続ミス(回線不調)"
        puts e
        puts e.class
        puts "再接続（１０秒後)"
        $stdout.flush
        $stderr.flush
        sleep 10
        retry 
     rescue => e 
       puts e
       retry
  end
  def notify(mailbox)
    mailbox.mail_threads.each{|t| 
      `growlnotify -a ./GmailIcon.png --image ./GmailIcon.png -n 'gmail notification'  -m '#{t.from}\n#{t.body_intro}' -t '#{t.subject}'`
    }
  end
end
class Thread
  def abort_on_exception=(bool)
      puts "abort_on_exception=#{bool} called but we ignored!!!"
  end
end


