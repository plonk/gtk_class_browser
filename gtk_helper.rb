# -*- coding: utf-8 -*-
module GtkHelper
  def create(klass, *args, &block)
    if args.last.is_a? Hash
      options = args.pop
    else
      options = Hash.new
    end
    widget = klass.new(*args)
    
    callbacks, normal = options.keys.partition { |sym| sym =~ /^on_/ }

    # オプション引数の処理
    callbacks.each do |name|
      callback = options[name]
      signal = name.to_s.sub(/\Aon_/, '')
      widget.signal_connect(signal, &callback)
    end

    normal.each do |name|
      value = options[name]
      widget.send(name.to_s + "=", value)
    end

    if block
      block.call(widget)
    end

    widget
  end

  def head(str)
    label = Gtk::Label.new(str+":")
    label.xalign = 1
    label.yalign = 0
    return label
  end

  def cell(str)
    label = Gtk::Label.new(str)
    label.selectable = true
    label.yalign = 0
    label.xalign = 0
    return label
  end    
end
