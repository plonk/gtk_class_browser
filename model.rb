require 'observer'

class Model
  include Observable

  attr_reader(:instance_methods,
              :class_methods,
              :signals,
              :selected_class,
              :classes,
              :info_text) # i like the color
  
  STOP_CLASSES = [Kernel, Object, BasicObject]

  def initialize
    load_classes
  end

  def notify
    changed
    notify_observers
  end

  def load_classes
    @classes = Gtk.constants
      .map{|c| eval("Gtk::#{c}")}
      .sort_by(&:to_s)
      .select{|c| c.class==Class}
    @instance_methods = []
    @class_methods = []
    @signals = []
    @info_text = ''
    changed
    notify_observers
  end

  def selected_class= klass
    return unless @classes.include? klass

    @instance_methods = klass.instance_methods(true)
      .sort
      .map { |sym| klass.instance_method(sym) }
      .reject { |m| STOP_CLASSES.include? m.owner  }

    @class_methods = klass.singleton_methods(true)
      .sort
      .map { |sym| klass.method(sym) }

    @signals = klass.respond_to?(:signals) ? klass.signals : []

    info = klass.ancestors.take_while{|x| x != ::Object}.map(&:to_s).join(' < ')
    info += "\n#{@instance_methods.size} instance methods"
    info += ", #{@class_methods.size} class methods"
    info += ", #{@signals.size} signals"

    @info_text = info
    changed
    notify_observers
  end
end
