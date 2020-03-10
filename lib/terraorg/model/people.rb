# Copyright 2019-2020 LiveRamp Holdings, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'terraorg/model/person'

class People
  attr_accessor :inactive

  def initialize(okta: nil, cache_file: nil)
    @okta = okta
    @people = {}
    @inactive = []
    @cache_file = cache_file

    load_cache! if @cache_file
  end

  def get_or_create!(id)
    p = @people[id]
    return p if p

    p = Person.new(id, okta: @okta)
    if p.active?
      @people[id] = p
    else
      @people.delete(id)
      @inactive.push p
    end
    save_cache! if @cache_file
    return p
  end

  def load_cache!
    return unless File.exist?(@cache_file)

    JSON.parse(File.read(@cache_file)).each do |id, cache|
      @people[id] = Person.new(id, cached: cache)
    end
  end

  def save_cache!
    # Atomic write cache file
    cf_new = "#{@cache_file}.new"
    File.write(cf_new, @people.to_json)
    File.rename(cf_new, @cache_file)
  end
end
