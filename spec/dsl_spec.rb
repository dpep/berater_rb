require 'berater/dsl'

describe Berater::DSL do
  def check(expected, &block)
    expect(Berater::DSL.eval(&block)).to eq expected
  end

  context 'rate mode' do
    it 'has keywords' do
      check(:second) { second }
      check(:minute) { minute }
      check(:hour) { hour }
    end

    it 'parses' do
      check([ 1, interval: :second ]) { 1.per second }
      check([ 3, interval: :minute ]) { 3.per minute }
      check([ 5, interval: :hour ]) { 5.every hour }
    end

    it 'cleans up afterward' do
      check([ 1, interval: :second ]) { 1.per second }

      expect(Integer).not_to respond_to(:per)
      expect(Integer).not_to respond_to(:every)
    end

    it 'works with variables' do
      count = 1
      interval = :second

      check([ count, interval: interval ]) { count.per interval }
    end
  end

  context 'concurrency mode' do
    it 'parses' do
      check([ 1 ]) { 1.at_once }
      check([ 3 ]) { 3.at_a_time }
      check([ 5 ]) { 5.concurrently }
    end

    it 'cleans up afterward' do
      check([ 1 ]) { 1.at_once }

      expect(Integer).not_to respond_to(:at_once)
      expect(Integer).not_to respond_to(:at_a_time)
      expect(Integer).not_to respond_to(:concurrently)
    end

    it 'works with constants' do
      class Foo
        CAPACITY = 3
      end

      check([ Foo::CAPACITY ]) { Foo::CAPACITY.at_once }
    end
  end

end
