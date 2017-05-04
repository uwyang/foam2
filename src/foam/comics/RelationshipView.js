/**
 * @license
 * Copyright 2016 Google Inc. All Rights Reserved.
 * Copyright 2017 The FOAM Authors. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

foam.CLASS({
  package: 'foam.comics',
  name: 'RelationshipView',
  extends: 'foam.u2.View',
  requires: [
    'foam.dao.RelationshipPropertyValue',
    'foam.dao.RelationshipController'
  ],
  exports: [
    'controller as data'
  ],
  properties: [
    {
      name: 'data',
      adapt: function(_, r) {
        if ( this.RelationshipPropertyValue.isInstance(r) ) {
          return this.RelationshipController.create({
            relationship: r
          });
        }
        return r;
      }
    },
    {
      class: 'FObjectProperty',
      of: 'foam.comics.DAOController',
      name: 'controller',
      expression: function(data) {
        return this.RelationshipController.create({
          data: data.dao,
          targetDAO: data.targetDAO,
          junctionDAO: data.junctionDAO
        });
      }
    }
  ],

  methods: [
    function initE() {
      this.tag(this.RelationshipControllerView)
    }
  ]
});