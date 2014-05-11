classdef Element
    properties
        type
        coords
        normals
        thickness
    end
    properties (Dependent)
        n_nodes
        v3
    end
    methods
        function obj = Element(type,coords,normals,t_in)
        % function obj = Element(type,coords,normals,t_in)
%             require(size(coords,1)==4, ...
%                 'ArgumentError: only 4 nodes');
%             require(size(coords)==size(normals), ...
%                 'ArgumentError: coords and normals should have same size');
            obj.coords = coords;
            obj.thickness = t_in;
            obj.normals = normals;
            obj.type = type;
        end
        function B = B(element,dofs_per_node,ksi,eta,zeta)
            % Prepare values
            v = element.normals;
            N  = element.shapefuns(ksi,eta);
            jac = element.jacobian(ksi,eta,zeta);
            invJac = jac \ eye(3);
            dN = invJac(:,1:2)*element.shapefunsder(ksi,eta);

            B  = zeros(6,element.n_nodes*dofs_per_node);
            % B matrix has the same structure for each node and comes from
            % putting all the B_coords next to each other.
            % Loop through the mesh.connect coords and get each B_node, then add it
            % to its columns in the B matrix
            for n = 1:element.n_nodes
                v1 = v(:,1,n);
                v2 = v(:,2,n);
                dZN = dN(:,n)*zeta + N(n)*invJac(:,3);
                aux1 = [ dN(1,n)         0          0
                                 0  dN(2,n)         0
                                 0          0  dN(3,n)
                         dN(2,n) dN(1,n)         0
                                 0  dN(3,n) dN(2,n)
                         dN(3,n)         0  dN(1,n) ];

                aux2 = [ -v2.*dZN                        v1.*dZN
                         -v2(1)*dZN(2) - v2(2)*dZN(1)    v1(1)*dZN(2) + v1(2)*dZN(1)
                         -v2(2)*dZN(3) - v2(3)*dZN(2)    v1(2)*dZN(3) + v1(3)*dZN(2)
                         -v2(1)*dZN(3) - v2(3)*dZN(1)    v1(1)*dZN(3) + v1(3)*dZN(1) ]*0.5*element.thickness(n);
                B(:,index_range(dofs_per_node,n)) = [aux1 aux2];
            end
        end
        function jac = jacobian(element,ksi,eta,zeta)
            % jac_out = jacobian(element,ksi,eta,zeta)
            % jac_out [3x3][Float]: Jacobian Matrix
            % ksi, eta, zeta [Float] between [-1,1], checking done in N
            % Computes the jacobian for Shell Elements
            % Cook [6.7-2] gives Isoparametric Jacobian
            % Cook [12.5-4] & [12.5-2] gives Shells Derivatives.
            N  = element.shapefuns(ksi,eta);
            dN = element.shapefunsder(ksi,eta);
            v3 = element.v3;
            t = element.thickness;
            tt = [t; t; t];
            v3t = (v3.*tt)';
            jac = [ dN*(element.coords + zeta*v3t/2);
                N*(v3t)/2 ];
        end
        function out = get.n_nodes(element)
            % out = get.n_nodes(element)
            % Number of nodes in the element
            out = size(element.coords,1);
        end
        function out = get.v3(element)
            out = squeeze(element.normals(:,3,:));
        end
        function dN = shapefunsder(element,ksi,eta)
            require(isnumeric([ksi eta]), ...
                'ArgumentError: Both ksi and eta should be numeric')
            require(-1<=ksi && ksi<=1, ...
                'ArgumetnError: ksi should be -1<=ksi<=1')
            require(-1<=eta && eta<=1, ...
                'ArgumetnError: eta should be -1<=eta<=1')
            switch element.type
                case {'Q9', 'AHMAD9'}
                   dN = [   % dN ksi
                            0.25*eta*(-1+eta)*(2*ksi-1),    ...	
                            0.25*eta*(-1+eta)*(2*ksi+1),    ...	
                            0.25*eta*(1+eta)*(2*ksi+1),     ...
                            0.25*eta*( 1+eta)*(2*ksi-1),    ...
                            -ksi*eta*(-1+eta),              ...
                            -1/2*(-1+eta)*(1+eta)*(2*ksi+1),...
                            -ksi*eta*(1+eta),               ...
                            -1/2*(-1+eta)*(1+eta)*(2*ksi-1),...
                            2*ksi*(-1+eta)*(1+eta);
                            % dN eta
                            0.25*ksi*(-1+2*eta)*(ksi-1),    ...
                            0.25*ksi*(-1+2*eta)*(1+ksi),    ...
                            0.25*ksi*(2*eta+1)*(1+ksi),     ...
                            0.25*ksi*(2*eta+1)*(ksi-1),     ...  
                            -0.5*(ksi-1)*(1+ksi)*(-1+2*eta),...
                            -ksi*eta*(1+ksi),               ...
                            -0.5*(ksi-1)*(1+ksi)*(2*eta+1), ...
                            -ksi*eta*(ksi-1),               ...
                            2*(ksi-1)*(1+ksi)*eta ];
                case {'Q8', 'AHMAD8'}
                    dN = [  % dN ksi
                            -0.25*(-1+eta)*(eta+2*ksi),     ...
                            -0.25*(-1+eta)*(-eta+2*ksi),    ...
                            0.25*(1+eta)*(eta+2*ksi),       ...
                            0.25*(1+eta)*(-eta+2*ksi),      ...
                            ksi*(-1+eta),                   ...
                            -0.5*(-1+eta)*(1+eta),          ...
                            -ksi*(1+eta),                   ...
                            0.5*(-1+eta)*(1+eta);
                            % dN deta
                            -0.25*(-1+ksi)*(ksi+2*eta),     ...
                            -0.25*(1+ksi)*(ksi-2*eta),      ...
                            0.25*(1+ksi)*(ksi+2*eta),       ...
                            0.25*(-1+ksi)*(ksi-2*eta),      ...
                            0.5*(-1+ksi)*(1+ksi),           ...
                            -(1+ksi)*eta,                   ...
                            -0.5*(-1+ksi)*(1+ksi),          ...
                            (-1+ksi)*eta ];
                case {'Q4', 'AHMAD4'}
                    dN = [  % dN ksi
                            -0.25*(1 - eta),    ...
                            0.25*(1 - eta),     ...
                            0.25*(1 + eta),     ...
                            -0.25*(1 + eta)
                            % dN deta
                            -0.25*(1 - ksi),    ...
                            -0.25*(1 + ksi),    ...
                            0.25*(1 + ksi),     ...
                            0.25*(1 - ksi) ];
                    
            end
        end
        function N = shapefuns(element,ksi,eta)
            require(isnumeric([ksi eta]), ...
                'ArgumentError: Both ksi and eta should be numeric')
            require(-1<=ksi && ksi<=1, ...
                'ArgumetnError: ksi should be -1<=ksi<=1')
            require(-1<=eta && eta<=1, ...
                'ArgumetnError: eta should be -1<=eta<=1')
            switch element.type
                case {'Q4', 'AHMAD4'}
                    N4 = 0.25*(1 - ksi)*(1 + eta);
                    N3 = 0.25*(1 + ksi)*(1 + eta);
                    N2 = 0.25*(1 + ksi)*(1 - eta);
                    N1 = 0.25*(1 - ksi)*(1 - eta);
                    N = [N1 N2 N3 N4];
                                       
                case {'Q8','AHMAD8'}
                    N8 = 0.50*(1 - ksi  )*(1 - eta^2);
                    N7 = 0.50*(1 - ksi^2)*(1 + eta  );
                    N6 = 0.50*(1 + ksi  )*(1 - eta^2);
                    N5 = 0.50*(1 - ksi^2)*(1 - eta  );
                    N4 = 0.25*(1 - ksi  )*(1 + eta  ) - 0.5*(N7 + N8);
                    N3 = 0.25*(1 + ksi  )*(1 + eta  ) - 0.5*(N6 + N7);
                    N2 = 0.25*(1 + ksi  )*(1 - eta  ) - 0.5*(N5 + N6);
                    N1 = 0.25*(1 - ksi  )*(1 - eta  ) - 0.5*(N5 + N8);
                    N = [N1 N2 N3 N4 N5 N6 N7 N8];
                    
                case {'Q9','AHMAD9'}
                    N9 =      (1 - ksi^2)*(1 - eta^2);
                    N8 = 0.50*(1 - ksi  )*(1 - eta^2) - 0.5*N9;
                    N7 = 0.50*(1 - ksi^2)*(1 + eta  ) - 0.5*N9;
                    N6 = 0.50*(1 + ksi  )*(1 - eta^2) - 0.5*N9;
                    N5 = 0.50*(1 - ksi^2)*(1 - eta  ) - 0.5*N9;
                    N4 = 0.25*(1 - ksi  )*(1 + eta  ) - 0.5*(N7 + N8 + 0.5*N9);
                    N3 = 0.25*(1 + ksi  )*(1 + eta  ) - 0.5*(N6 + N7 + 0.5*N9);
                    N2 = 0.25*(1 + ksi  )*(1 - eta  ) - 0.5*(N5 + N6 + 0.5*N9);
                    N1 = 0.25*(1 - ksi  )*(1 - eta  ) - 0.5*(N5 + N8 + 0.5*N9);
                    N  = [N1 N2 N3 N4 N5 N6 N7 N8 N9];                    
            end
        end
    end
    methods (Static)
        function T = T(jac)
            % sistema de coordenadas local 123 en [ksi eta zeta]
            dir1 = jac(1,:);
            dir3 = cross(dir1,jac(2,:));
            dir2 = cross(dir3,dir1);

            % Transformation of Strain, Cook pg 212: 
            % Cook [7.3-5]
            M1 = [ dir1/norm(dir1); dir2/norm(dir2); dir3/norm(dir3) ];
            M2 = M1(:,[2 3 1]);
            M3 = M1([2 3 1],:);
            M4 = M2([2 3 1],:);
            T = [ M1.^2     M1.*M2;
                  2*M1.*M3  M1.*M4 + M3.*M2 ];
            % Since sigma_zz is ignored, we eliminate the appropriate row.
            T(3,:) = [];
        end
        function NN = shape_to_diag(dim,N)
            % NN = shape_to_diag(dim,N)
            % NN [Float][dim x n_nodes]: Repeated values of N
            % N [Float] [1 x n_nodes]: Evaluated shape functions
            % dim [Int]: dimension of the problem, 2 or 3.
            % Rearranges for some surface integral for loads
            n_nodes = length(N);
            NN = zeros(dim,n_nodes);
            I = eye(dim);
            for n = 1:n_nodes
                i = index_range(dim,n);
                NN(:,i) = N(n)*I;
            end
        end
        function N_out = N_ShellQ4(element,xi,eta,mu)
            % Not really used!!!
            require(isnumeric(mu), ...
                'ArgumentError: xi, eta, and mu should be numeric')
            require(-1<=mu && mu<=1, ...
                'ArgumentError: mu should is not -1<=mu<=1')
            % Need to check the way it works with Jacobian
            N_out = Element.N_Q4(xi,eta)*mu*element.normals;
        end
        function N_out = N_Q4(xi,eta)
            %  Notes:
            %     1st node at (-1,-1), 3rd node at (-1,1)
            %     4th node at (1,1), 2nd node at (1,-1)
            require(isnumeric([xi eta]), ...
                'ArgumentError: Both xi and eta should be numeric')
            require(-1<=xi && xi<=1, ...
                'ArgumetnError: xi should be -1<=xi<=1')
            require(-1<=eta && eta<=1, ...
                'ArgumetnError: eta should be -1<=eta<=1')
            N_out = zeros(1,4);
            N_out(1) = 0.25*(1-xi)*(1-eta);
            N_out(3) = 0.25*(1+xi)*(1-eta);
            N_out(2) = 0.25*(1-xi)*(1+eta);
            N_out(4) = 0.25*(1+xi)*(1+eta);
        end
        function dNdxiQ4_out = dNdxi_Q4(xi,eta)
            % derivatives
            require(isnumeric([xi eta]), ...
                'ArgumentError: Both ksi and eta should be numeric')
            require(-1<=xi && xi<=1, ...
                'ArgumetnError: ksi should be -1<=ksii<=1')
            require(-1<=eta && eta<=1, ...
                'ArgumetnError: eta should be -1<=eta<=1')
            dNdxiQ4_out = zeros(1,4);
            dNdxiQ4_out(1) = -0.25*(1-eta);
            dNdxiQ4_out(2) = 0.25*(1-eta);
            dNdxiQ4_out(3) = -0.25*(1+eta);
            dNdxiQ4_out(4) = 0.25*(1+eta);
        end
        function dNdetaQ4_out = dNeta_Q4(xi,eta)
            % derivatives
            require(isnumeric([xi eta]), ...
                'ArgumentError: Both xi and eta should be numeric')
            require(-1<=xi && xi<=1, ...
                'ArgumetnError: xi should be -1<=xi<=1')
            require(-1<=eta && eta<=1, ...
                'ArgumetnError: eta should be -1<=eta<=1')
            dNdetaQ4_out = zeros(1,4);
            dNdetaQ4_out(1) = -0.25*(1-xi);
            dNdetaQ4_out(2) = -0.25*(1+xi);
            dNdetaQ4_out(3) = 0.25*(1-xi);
            dNdetaQ4_out(4) = 0.25*(1+xi);
        end
    end
end
