// Copyright 2016 VMware, Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package network

import (
	"fmt"
	"net"
	"sync"

	"github.com/vmware/vic/lib/portlayer/exec"
)

var (
	defaultSubnet *net.IPNet
)

const (
	bridgeScopeType   = "bridge"
	externalScopeType = "external"
)

type Scope struct {
	sync.Mutex

	id         string
	name       string
	scopeType  string
	subnet     net.IPNet
	gateway    net.IP
	dns        []net.IP
	ipam       *IPAM
	containers map[exec.ID]*Container
	endpoints  []*Endpoint
	space      *AddressSpace

	NetworkName string // portgroup name specified in VCH guestinfo (e.g. under "networks/bridge")
}

type IPAM struct {
	pools  []string
	spaces []*AddressSpace
}

func init() {
	_, defaultSubnet, _ = net.ParseCIDR("0.0.0.0/16")
}

func (s *Scope) Name() string {
	return s.name
}

func (s *Scope) ID() string {
	return s.id
}

func (s *Scope) Type() string {
	return s.scopeType
}

func (s *Scope) IPAM() *IPAM {
	return s.ipam
}

func (s *Scope) reserveEndpointIP(e *Endpoint) error {
	// reserve an ip address
	var err error
	for _, p := range s.ipam.spaces {
		if e.static {
			if err = p.ReserveIP4(e.ip); err == nil {
				break
			}
		} else {
			var ip net.IP
			if ip, err = p.ReserveNextIP4(); err == nil {
				e.ip = ip
				break
			}
		}
	}

	return err
}

func (s *Scope) releaseEndpointIP(e *Endpoint) error {
	for _, p := range s.ipam.spaces {
		if err := p.ReleaseIP4(e.ip); err == nil {
			if !e.static {
				e.ip = net.IPv4(0, 0, 0, 0)
			}
			return nil
		}
	}

	return fmt.Errorf("could not release IP for endpoint")
}

func (s *Scope) addContainer(con *Container, ip *net.IP) (*Endpoint, error) {
	s.Lock()
	defer s.Unlock()

	if con == nil {
		return nil, fmt.Errorf("container is nil")
	}

	_, ok := s.containers[con.id]
	if ok {
		return nil, DuplicateResourceError{resID: con.id.String()}
	}

	e := newEndpoint(con, s, ip, s.subnet, s.gateway, nil)
	if ip != nil {
		e.static = true
	}

	con.addEndpoint(e)
	s.endpoints = append(s.endpoints, e)
	s.containers[con.id] = con
	return e, nil
}

func (s *Scope) removeContainer(con *Container) error {
	s.Lock()
	defer s.Unlock()

	c, ok := s.containers[con.ID()]
	if !ok || c != con {
		return ResourceNotFoundError{}
	}

	e := c.Endpoint(s)
	if e == nil {
		return ResourceNotFoundError{}
	}

	if e.IsBound() {
		return fmt.Errorf("unbind container first")
	}

	delete(s.containers, c.id)
	s.endpoints = removeEndpointHelper(e, s.endpoints)
	c.removeEndpoint(e)
	return nil
}

func (s *Scope) bindContainer(con *Container) error {
	s.Lock()
	defer s.Unlock()

	if con == nil {
		return fmt.Errorf("invalid args")
	}

	c, ok := s.containers[con.ID()]
	if !ok || c != con {
		return ResourceNotFoundError{}
	}

	return c.bind(s)
}

func (s *Scope) unbindContainer(con *Container) error {
	s.Lock()
	defer s.Unlock()

	if con == nil {
		return fmt.Errorf("invalid args")
	}

	c, ok := s.containers[con.ID()]
	if !ok || c != con {
		return ResourceNotFoundError{}
	}

	return c.unbind(s)
}

func (s *Scope) Containers() []*Container {
	s.Lock()
	defer s.Unlock()

	containers := make([]*Container, len(s.containers))
	i := 0
	for _, c := range s.containers {
		containers[i] = c
		i++
	}

	return containers
}

func (s *Scope) Container(id exec.ID) *Container {
	s.Lock()
	defer s.Unlock()

	if c, ok := s.containers[id]; ok {
		return c
	}

	return nil
}

func (s *Scope) Endpoints() []*Endpoint {
	return s.endpoints
}

func (s *Scope) Subnet() *net.IPNet {
	return &s.subnet
}

func (s *Scope) Gateway() net.IP {
	return s.gateway
}

func (s *Scope) DNS() []net.IP {
	return s.dns
}

func (i *IPAM) Pools() []string {
	return i.pools
}
